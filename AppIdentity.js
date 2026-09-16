function normalized(value) {
  return String(value || "").trim().toLowerCase()
}

function desktopId(value) {
  return normalized(value).replace(/\.desktop$/, "")
}

function webApp(appClass) {
  const raw = String(appClass || "").trim()
  const browser = /^(?:chrome|chromium|brave|msedge|microsoft-edge|vivaldi)-(.+)$/i.exec(raw)
  const identity = browser ? browser[1] : raw
  const host = /^([a-z0-9.-]+\.[a-z0-9-]+)_/i.exec(identity)
  const appId = /^(?:_crx_)?([a-p]{32})(?:-|$)/.exec(identity)
  if (!host && !appId) return null
  return { identity: identity, host: host ? host[1].toLowerCase() : "", appId: appId ? appId[1] : "" }
}

function urlIdentity(value) {
  const match = /^https?:\/\/([^/?#\s]+)([^?#\s]*)/i.exec(value)
  if (!match || match[1].indexOf("@") !== -1) return null
  const host = match[1].toLowerCase().replace(/:\d+$/, "")
  // Chromium forms URL app IDs from host + '_' + path, with slashes replaced.
  const path = match[2] || "/"
  return { host: host, identity: host + "_" + path.replace(/[<>:"/\\|?*\x00-\x1f]/g, "_") }
}

function matchesIdentity(actual, expected) {
  return actual === expected || actual.indexOf(expected + "-") === 0
}

function unique(entries) {
  return entries.length === 1 ? entries[0] : null
}

function findEntry(appClass, entries) {
  const raw = normalized(appClass)
  const exact = entries.filter(function(entry) {
    return desktopId(entry.id) === raw || (entry.startupClass && normalized(entry.startupClass) === raw)
  })
  if (exact.length) return unique(exact)

  const web = webApp(appClass)
  if (!web) return null
  let precise = [], bestLength = 0
  const sameHost = [], aliases = []
  entries.forEach(function(entry) {
    // Read the parsed Exec arguments as data; never run a launcher to identify it.
    const command = entry.command || []
    let matchLength = 0, hostMatch = false
    for (let i = 0; i < command.length; i++) {
      const arg = String(command[i])
      const url = urlIdentity(arg.replace(/^--app=/, ""))
      if (url && web.host === url.host) {
        hostMatch = true
        if (matchesIdentity(web.identity, url.identity)) matchLength = Math.max(matchLength, url.identity.length)
      }
      if (web.appId && (arg === "--app-id=" + web.appId || (arg === "--app-id" && command[i + 1] === web.appId)))
        matchLength = web.appId.length
    }
    if (matchLength > bestLength) {
      precise = []
      bestLength = matchLength
    }
    if (matchLength && matchLength === bestLength) precise.push(entry)
    if (hostMatch) sameHost.push(entry)

    // URL-less wrappers can match the site label, never arbitrary subdomains.
    // Account for common second-level country suffixes without assuming every
    // country's registry uses them. This is a display heuristic, not identity proof.
    const labels = web.host.split(".")
    const countrySuffix = labels.length > 2 && labels[labels.length - 1].length === 2
      && /^(co|com|org|net|gov|ac)$/.test(labels[labels.length - 2])
    const label = labels[labels.length - (countrySuffix ? 3 : 2)]
    if (label && !/^(www|app|apps|web|mail)$/.test(label)
        && (normalized(entry.name) === label || desktopId(entry.id) === label)) aliases.push(entry)
  })
  if (precise.length) return unique(precise)
  if (sameHost.length) return unique(sameHost)
  return unique(aliases)
}

function fallbackName(appClass) {
  const raw = String(appClass || "").trim()
  if (!raw) return "Unknown"
  const web = webApp(raw)
  if (web) return web.host || "Web app"
  let name = raw.replace(/^steam_app_/i, "")
  if (name.indexOf(".") !== -1) name = name.split(".").pop()
  name = name.replace(/[_-]+/g, " ").trim()
  return name.replace(/(^|\s)\S/g, function(letter) { return letter.toUpperCase() })
}
