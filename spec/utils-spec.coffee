describe "the function `filterLastDays`", ->
  { filterLastDays, format } = require("../src/utils.coffee")
  moment = require "moment"

  it "is a function", ->
    expect(filterLastDays).to.be.a "function"

  it "returns an object with `valid` and `expired` properties", ->
    result = filterLastDays({})
    expect(result).to.be.a "object"
    expect(result).to.have.property "valid"
    expect(result).to.have.property "expired"

  it "keeps indices which are not older than 1 day", ->
    timestampNow = moment().format format
    timestampYesterday = moment().subtract(1, "day").format format
    timestampDayBeforeYesterday = moment().subtract(2, "day").format format

    input = []
    input["foo-#{timestampNow}"] = []
    input["foo-#{timestampYesterday}"] = []
    input["foo-#{timestampDayBeforeYesterday}"] = []

    { valid, expired } = filterLastDays(input,1)

    expect(valid).to.have.keys(["foo-#{timestampNow}", "foo-#{timestampYesterday}"])
    expect(expired).to.have.keys(["foo-#{timestampDayBeforeYesterday}"])

describe "the function `mapIndicesToAliases`", ->
  mapIndicesToAliases = require("../src/utils.coffee").mapIndicesToAliases

  it "returns an empty array for no/falsy input", ->
    expect(mapIndicesToAliases()).to.be.eql []
    expect(mapIndicesToAliases(null)).to.be.eql []
    expect(mapIndicesToAliases(undefined)).to.be.eql []

  it "returns an array with the index as key and the alias as value", ->
    input = {
      'index1': { aliases: { 'alias1-for-index1': {} } }
      'index2': { aliases: {} }
      'index3': { aliases: { 'alias1-for-index3': {}, 'alias2-for-index3': {} } }
    }

    result = mapIndicesToAliases input

    expect(result).to.be.a "array"
    expect(result).to.have.keys [ 'index1', 'index2', 'index3' ]
    expect(result['index1']).to.be.lengthOf(1).and.to.have.members [ 'alias1-for-index1' ]
    expect(result['index2']).to.be.lengthOf(0)
    expect(result['index3']).to.be.lengthOf(2).and.to.have.members [ 'alias1-for-index3', 'alias2-for-index3' ]