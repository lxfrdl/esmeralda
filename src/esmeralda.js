// ElasticSearch Managmenet Environment for Real Advanced Lightweigt Descriptive Actions (ESmeralda)
/* eslint-disable no-console */
const Promise = require('bluebird');
const rl = require('readline').createInterface({
  input: process.stdin,
  output: process.stdout
});
const ask = Promise.promisify((question, callback) => {
  rl.question(question, callback.bind(null, null));
});
const elasticsearch = require("elasticsearch");
const moment = require("moment");
const {
  help,
  host,
  port,
  swap,
  activate,
  create,
  list,
  remove,
  older
} = require('minimist')(process.argv.slice(2), {
  alias: {
    h: "help",
    H: "host",
    p: "port",
    s: "swap",
    a: "activate",
    c: "create",
    l: "list",
    r: "remove",
    o: "older"
  },
  default: {
    host: "127.0.0.1",
    port: 9200,
    older: 1,
    list: "*"
  }
});

const client = new elasticsearch.Client({
  host: `${host}:${port}`,
  defer: function () {
    return Promise.defer();
  }
  // , log: "trace"
});

const format = "YYYYMMDDHHmmss";

const stop = (code) => (typeof code === "number" ? process.exit(code) : process.exit());

const printIndicesWithAliases = (result) => {
  for (const index in result) {
    if ( result.hasOwnProperty(index) ) {
      const aliases = result[index];
      console.log("\n- [index] %s", index);
      for (const key in aliases) {
        if (aliases.hasOwnProperty(key)) {
          const alias = aliases[key];
          console.log("  - [alias] %s", alias);
        }
      }
    }
  }
};

const deleteAlias = (name) => {
  console.log("Deleting alias '%s'.", name);
  return client.indices.deleteAlias({
    index: "_all",
    name
  });
};

const createAlias = (name, index) => {
  console.log("Creating alias '%s' pointing to '%s'.", name, index);
  return client.indices.putAlias({
    name,
    index
  });
};

const filterLastDays = (result) => {
  const valid = [];
  const expired = [];
  const pattern = new RegExp("([0-9]{14})");
  for (const index in result) {
    if (result.hasOwnProperty(index)) {
      const aliases = result[index];
      const indexTimestamp = pattern.exec(index)[0];
      const diff = moment().diff(moment(indexTimestamp,format),"days");
      if ( diff <= Number(older) ) {
        valid[index] = aliases;
      } else {
        expired[index] = aliases;
      }
    }
  }
  return { valid, expired };
};

const stopIfNotString = (s) => {
  if ( typeof s !== "string" ) {
    console.error("The given argument does not seem to be a string!");
    stop(1);
  }
};

const deleteAliasIfExists = (name) => {
  return client.indices.existsAlias({
    name
  })
    .then((exists) => {
      if ( !exists ) {
        console.log("Alias '%s' does not exist.", name);
        return exists;
      }
      return deleteAlias(name);
    });
};
const mapIndicesToAliases = (result) => {
  const output = [];
  const indices = Object.keys(result);
  for (const index of indices) {
    output[index] = Object.keys(result[index].aliases);
  }
  return output;
};

const findIndices = (index) => {
  return client.indices.exists({
    index
  })
    .then((exists) => {
      if ( !exists ) {
        console.error(`No indices found matching '${index}'`,index);
        stop(1);
      }
      return client.indices.get({
        index
      });
    })
    .then((result) => {
      const count = Object.keys(result).length;
      if (count === 0) {
        console.log("Found no indices matching '%s'.", index);
        return stop();
      }
      console.log("Found %d index/indices matching '%s':", count, index);
      return mapIndicesToAliases(result);
    });
};

if ( create ) {
  stopIfNotString(create);
  const timestamp = moment().format(format);
  const newIndexName = `${create}-${timestamp}`;
  const writeAlias = `${create}-write`;

  // create new index
  console.log("Creating index called '%s'.", newIndexName);
  client.indices.create({
    index: newIndexName
  })
    .then(() => (deleteAliasIfExists(writeAlias)))
    .then(() => (createAlias(writeAlias, newIndexName)))
    .then(stop);
}

if ( help ) {
  const text =
`
Usage: node ESmeralda.js [OPTIONS...]

  Options:

  -h, -help\t\t\t\t displays me :)
  -H, -host HOST\t\t\t default: 127.0.0.1 | sets the ES host
  -p, -port PORT\t\t\t default: 9200 | sets the ES port
  -c, -create APP-TYPE\t\t\t creates an index (APP-TYPE-${format}) and assigns an alias (APP-TYPE-write)
  -s, -swap APP-TYPE\t\t\t deletes (if exitsts) the alias 'APP-TYPE-write' and assign to the index the alias 'APP-TYPE'
  -a, -activate APP-TYPE-${format}\t deletes (if exitsts) the alias 'APP-TYPE' ; assigns an alias 'APP-TYPE'
  -l, -list\t\t\t\t default: * |
  -r, -remove APP-TYPE\t\t\t deletes expired indices
  -o, -older\t\t\t\t default: 1 | sets the limit for valid indices in days
`;
  console.log(text);
  stop();
}

if ( swap ) {
  const writeAlias = `${swap}-write`;
  // check if a write alias exists
  client.indices.existsAlias({
    name: writeAlias
  })
    .then((exists) => {
      // if not: no good!!1
      if (!exists) {
        console.error("Found no existing write alias '%s', which could be swapped to!", writeAlias);
        stop(1);
      }
      // otherwise continue
      return exists;
    })
    .then(() => (deleteAliasIfExists(swap)))
    .then(() => {
      // ask for all indices with the write alias
      return client.indices.getAlias({
        name: writeAlias
      });
    })
    .then((IndicesToAlias) => {
      // we are expecting to find exactly one index
      // from which is going to be read
      // if we got more than one index, something is wrong
      const indices = Object.keys(IndicesToAlias);
      if (indices.length > 1) {
        console.error("Found more than 1 index a write alias is pointing to!");
        stop(1);
      }
      // return the only the index name
      return indices[0];
    })
    .then((index) => (createAlias(swap, index)))
    .then(() => (deleteAlias(writeAlias)))
    .then(stop);
}

if ( activate ) {
  const pattern = new RegExp("([a-zA-Z-]+)[^-0-9]");
  const readAlias = pattern.exec(activate)[0];
  deleteAliasIfExists(readAlias)
    .then(() => (createAlias(readAlias, activate)))
    .then(stop);
}

if ( list ) {
  const index = list;
  findIndices(index)
    .then((result) => (printIndicesWithAliases(result)))
    .then(()=>(/*to overwrite error code returned from 'findAndPrintIndices'*/
      null
    ))
    .then(stop);
}

if ( remove ) {
  stopIfNotString(remove);
  const index = remove;
  findIndices(index)
    .then(filterLastDays)
    .then(({valid, expired}) => {
      const countValid = Object.keys(valid).length;
      if ( countValid > 0) {
        console.log("\nFollowing %d index/indices are still valid:", countValid);
        printIndicesWithAliases(valid);
      }
      const countExpired = Object.keys(expired).length;
      if ( countExpired > 0 ) {
        console.log("\nFollowing %d index/indices are expired and going to be deleted:", countExpired);
        printIndicesWithAliases(expired);
      }
      return expired;
    })
    .then((expired) => {
      const count = Object.keys(expired).length;
      if (count === 0) {
        return stop();
      }
      return ask(`\nDo you really want to delete ${count} index/indices? [y/Y]: `)
        .then((answer) => {
          return {answer, expired};
        });
    })
    .then(({answer, expired}) => {
      if (answer.toLowerCase() !== "y") {
        console.log("Canceled deleting index/indices.");
        return;
      }
      console.log("\nDeleting index/indices...");
      return client.indices.delete({
        index: Object.keys(expired)
      });
    })
    .then(stop);
}
/* eslint-enable no-console */