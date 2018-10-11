
{ promisify } = require 'bluebird'
rl = require('readline').createInterface {
  input: process.stdin,
  output: process.stdout
}

# timestamp format
format = "YYYYMMDDHHmmss"

# regexp for timestamp
patternTimestamp = new RegExp "([0-9]{14})"

patternAlias = new RegExp "([a-zA-Z-]+)[^-0-9]"

moment = require "moment"

filterLastDays = ( result, older ) ->
  valid = []
  expired = []
  for own index, aliases of result
    indexTimestamp = patternTimestamp.exec(index)[0]
    diff = moment().diff moment(indexTimestamp,format), "days"
    if aliases.length > 0
      valid[index] = aliases
    else if typeof older == "string" && "none" == older.trim()
      expired[index] = aliases
    else if  diff <= Number older
      valid[index] = aliases
    else
      expired[index] = aliases

  {
    valid
    expired
  }

getIndexCount = ( obj ) ->
  Object.keys(obj).length

mapIndicesToAliases = (result) ->
  if !result then return []
  if result and Object.keys(result).length == 0 then return []
  output = []
  indices = Object.keys result
  for index in indices
    output[index] = Object.keys result[index].aliases
  output

stop = ( code ) ->
  if typeof code == "number" then process.exit(code) else process.exit()

stopIfNotString = ( s ) ->
  if typeof s != "string"
    console.error "The given argument does not seem to be a string!"
    stop 1

printIndicesWithAliases = ( result ) ->
  for own index, aliases of result
    console.log "\n- [index] %s", index
    for own key, alias of aliases
      console.log "  - [alias] %s", alias

ask = ( assumeYes ) ->
  promisify (question, callback) ->
    if assumeYes
      callback null, "y"
    else
      rl.question question, callback.bind null, null

module.exports = {
  format
  patternTimestamp
  filterLastDays
  mapIndicesToAliases
  stop
  printIndicesWithAliases
  stopIfNotString
  getIndexCount
  patternAlias
  ask
}