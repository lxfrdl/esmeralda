{
  stop
  mapIndicesToAliases
} = require("./utils")

createIndex = ( client ) ->
  ( index ) ->
    client.indices.create {
      index
    }

deleteAlias = ( client ) ->
  ( name ) ->
    console.log "Deleting alias '%s'.", name
    client.indices.deleteAlias {
      index: "_all"
      name
    }

createAlias = ( client ) ->
  ( name, index ) ->
    console.log "Creating alias '%s' pointing to '%s'.", name, index
    client.indices.putAlias {
      name
      index
    }

existsAlias = ( client ) ->
  ( name ) ->
    client.indices.existsAlias {
      name
    }

deleteAliasIfExists = ( client ) ->
  ( name ) ->
    existsAlias(client) name
    .then ( exists ) ->
      if exists
        deleteAlias(client) name
      else
        console.log "Alias '%s' does not exist.", name
        exists

findIndices = ( client ) ->
  ( index ) ->
    client.indices.exists {
      index
    }
    .then ( exists ) ->
      if ( !exists )
        console.error "No indices found matching '%{index}'",index
        # TODO: Soll das hier abgefangen werden??
        stop(1)
      client.indices.get {
        index
      }
    .then ( result ) ->
      count = Object.keys(result).length
      if ( count == 0 )
        console.log "Found no indices matching '%s'.", index
        stop()
      console.log "Found %d index/indices matching '%s':", count, index
      mapIndicesToAliases result

getAlias = ( client ) ->
  ( name ) ->
    client.indices.getAlias {
      name
    }

deleteIndices = ( client ) ->
  ( indices ) ->
    client.indices.delete {
      index: Object.keys indices
    }


module.exports = ( client ) -> {
  createIndex: createIndex client
  deleteAlias: deleteAlias client
  createAlias: createAlias client
  existsAlias: existsAlias client
  deleteAliasIfExists: deleteAliasIfExists client
  findIndices: findIndices client
  getAlias: getAlias client
  deleteIndices: deleteIndices client
}
