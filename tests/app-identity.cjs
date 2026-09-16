const assert = require('node:assert/strict')
const fs = require('node:fs')
const vm = require('node:vm')
const resolver = vm.createContext({})
vm.runInContext(fs.readFileSync('AppIdentity.js', 'utf8'), resolver)

const hey = { id: 'HEY', name: 'HEY', icon: 'hey', command: ['omarchy-webapp-handler-hey', '%u'] }
const basecamp = { id: 'Basecamp', name: 'Basecamp', icon: 'basecamp', command: ['omarchy-launch-webapp', 'https://launchpad.37signals.com'] }
const youtube = { id: 'YouTube', name: 'YouTube', icon: 'youtube', command: ['chromium', '--app=https://youtube.com/'] }
const entries = [hey, basecamp, youtube]
const find = (appClass, apps = entries) => resolver.findEntry(appClass, apps)

assert.equal(find('chrome-app.hey.com__-Default'), hey)
assert.equal(find('chrome-app.hey.com__-Profile-2'), hey)
assert.equal(find('chrome-launchpad.37signals.com__-Default'), basecamp)
assert.equal(find('brave-youtube.com__-Profile 3'), youtube)
assert.equal(find('youtube.com__'), youtube) // XWayland URL class
assert.equal(find('HEY'), hey)

const explicit = { id: 'custom', name: 'Custom', startupClass: 'chrome-app.hey.com__-Default' }
assert.equal(find(explicit.startupClass, entries.concat(explicit)), explicit)
assert.equal(find('chrome-app.hey.com__-Default', [hey, { ...hey, id: 'other' }]), null)
assert.equal(find('chrome-nothey.com__-Default'), null)
assert.equal(find('chrome-hey.com.evil.test__-Default'), null)
assert.equal(find('chrome-app.hey.co.uk__-Default'), hey)

const first = { id: 'first', name: 'First', command: ['browser', '--app=https://example.org/first'] }
const second = { id: 'second', name: 'Second', command: ['browser', '--app=https://example.org/second'] }
assert.equal(find('chrome-example.org__first-Default', [first, second]), first)
assert.equal(find('chrome-example.org__second-Default', [first, second]), second)
assert.equal(find('chrome-example.org__other-Default', [first, second]), null)
assert.equal(find('chrome-example.org__other-Default', [first]), first)
assert.equal(find('chrome-example.org.evil.test__first-Default', [first]), null)
const nested = { id: 'nested', name: 'Nested', command: ['browser', '--app=https://example.org/first-other'] }
assert.equal(find('chrome-example.org__first-other-Default', [first, nested]), nested)

const appId = 'abcdefghijklmnopabcdefghijklmnop'
const pwa = { id: 'pwa', name: 'Installed PWA', icon: 'pwa-icon', command: ['chromium', '--app-id=' + appId] }
assert.equal(find('chrome-' + appId + '-Default', [pwa]), pwa)
assert.equal(find('_crx_' + appId, [pwa]), pwa)
assert.equal(find('msedge-' + appId + '-Profile 1', [{ ...pwa, command: ['msedge', '--app-id', appId] }]).name, pwa.name)
assert.equal(find('chrome-' + appId + '-Default', [pwa, { ...pwa, id: 'other-profile' }]), null)

assert.equal(resolver.fallbackName('chrome-app.unknown.co.uk__-Profile 1'), 'app.unknown.co.uk')
assert.equal(resolver.fallbackName('chrome-' + appId + '-Default'), 'Web app')
assert.equal(resolver.fallbackName('org.example.NativeApp'), 'NativeApp')
assert.equal(resolver.fallbackName(''), 'Unknown')
assert.equal(find('foot'), null)
console.log('Web app launcher, profile, path, PWA, ambiguity, and fallback checks passed')
