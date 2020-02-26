# general node/npm imports
fs = require "fs"
path = require "path"
Promise = require 'bluebird'

elasticsearch = require("elasticsearch")
moment = require("moment")

# cli options from readme
yaml = require "js-yaml"
readme =  yaml.load fs.readFileSync path.join __dirname,  '../README.yaml'
automist = require("automist") readme
minimist = require "minimist"
argv = minimist process.argv.slice(2), automist.options()
{
  help
  list
  create
  activate
  swap
  remove
  hostname
  port
  older
  overrides
} = argv
# cause yes is reserved in cs
assumeYes = argv.yes

# elasticsearch client
hostname ?= "127.0.0.1"
port ?= 9200
client = new elasticsearch.Client {
  host: process.env.ES_URL || "#{hostname}:#{port}"
  defer: () ->
    Promise.defer()
  #, log: "trace"
}

actions = require("./esActions") client

if overrides?
  overriddenActions = require(path.resolve overrides) client
  for key,value of overriddenActions
    actions[key] = value

{
  deleteAlias
  createAlias
  deleteAliasIfExists
  findIndices
  createIndex
  getAlias
  existsAlias
  deleteIndices
} = actions

{
  printIndicesWithAliases
  stop
  stopIfNotString
  format
  patternTimestamp
  patternAlias
  mapIndicesToAliases
  filterLastDays
  ask
  getIndexCount
} = require("./utils")

ask = ask assumeYes

# default limit for days
older ?= 1

# check arguments for a matching action
if help
  console.log automist.help()
  stop()

else if list || typeof list == "string"
  index = if list == "" then "*" else list
  findIndices index
    .then printIndicesWithAliases
    .then stop

else if create
  stopIfNotString create
  timestamp = moment().format(format)
  newIndexName = "#{create}-#{timestamp}"
  writeAlias = "#{create}-write"

  console.log "Creating index called '%s'.", newIndexName
  createIndex newIndexName
  .then ->
    deleteAliasIfExists writeAlias
  .then ->
    createAlias writeAlias, newIndexName
  .then stop

else if activate
  readAlias  = (patternAlias.exec activate)[0]
  deleteAliasIfExists readAlias
  .then ->
    createAlias readAlias, activate
  .then stop

else if swap
  console.log "swap", swap
  writeAlias = "#{swap}-write"
  existsAlias writeAlias
  .then ( exists ) ->
    if ( !exists )
      console.error "Found no existing write alias '%s', which could be swapped to!", writeAlias
      stop 1
    exists
  .then ->
    deleteAliasIfExists swap
  .then ->
    getAlias writeAlias
  .then mapIndicesToAliases
  .then ( result ) ->
    if result.length > 1 # earlier we checked, if the alias exists. so it can't be 0
      console.error "Found more than 1 index a write alias is pointing to!"
      stop 1
    for index of result
      return index
  .then ( index ) ->
    createAlias swap, index
  .then ->
    deleteAlias writeAlias
  .then stop

else if remove
  index = remove
  findIndices index
  .then ( result ) ->
    filterLastDays result, older
  .then ({ valid, expired }) ->
    validCount = getIndexCount valid
    if validCount > 0
      console.log "\nFollowing %d index/indices are still valid:", validCount
      printIndicesWithAliases valid

    expiredCount = getIndexCount expired
    if expiredCount > 0
      console.log "\nFollowing %d index/indices are expired and going to be deleted:", expiredCount
      printIndicesWithAliases expired

    {
      expired
      expiredCount
    }
  .then ({ expired, expiredCount }) ->
    if expiredCount is 0
      stop()
    else
      ask "\nDo you really want to delete #{expiredCount} index/indices? [y/N]: "
      .then ( answer ) ->
        {
          answer
          expired
        }
  .then ({ answer, expired }) ->
    console.log answer
    if answer.toLowerCase() is "y"
      console.log "\nDeleting index/indices…"
      deleteIndices expired
    else
      console.log "Canceled deleting index/indices."
  .then stop

else
  stop()
