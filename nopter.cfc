component extends="foundry.core" {
    public any function init(args,cwd) {
        variables.path = require('path');
        variables._ = require("util");

        this.argv = new lib.argv(argumentCollection=arguments);
        //variables.wordwrap = require('wordwrap');
        
        /*  Hack an instance of Argv with process.argv into Argv
            so people can do
                require('optimist')(['--beeble=1','-z','zizzle']).argv
            to parse a list of args and
                require('optimist').argv
            to get a parsed version of process.argv.
        */

        // var inst = new lib.Argv(process.argv.slice(2));
        // Object.keys(inst).forEach(function (key) {
        //     Argv[key] = typeof inst[key] == 'function'
        //         ? inst[key].bind(inst)
        //         : inst[key];
        // });
        // rebase an absolute path to a relative one with respect to a base directory
        // exported for tests
        //exports.rebase = rebase;
        return this;
    }

    public any function rebase(base, dir) {
        var ds = path.normalize(dir).split('/').slice(1);
        var bs = path.normalize(base).split('/').slice(1);
        
        for (var i = 0; ds[i] && ds[i] == bs[i]; i++);
        ds.splice(0, i); bs.splice(0, i);
        
        var p = path.normalize(
            bs.map(function () { return '..' }).concat(ds).join('/')
        ).replace(/\/$/,'').replace(/^$/, '.');
        return p.match(/^[.\/]/) ? p : './' + p;
    };

    public any function setKey (obj, keys, value) {
        var o = obj;
        keys.slice(0,-1).forEach(function (key) {
            if (o[key] === undefined) o[key] = {};
            o = o[key];
        });
        
        var key = keys[keys.length - 1];
        if (o[key] === undefined || typeof o[key] === 'boolean') {
            o[key] = value;
        }
        else if (Array.isArray(o[key])) {
            o[key].push(value);
        }
        else {
            o[key] = [ o[key], value ];
        }
    }
}

