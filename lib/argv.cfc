component name="argv" {
	property name="argv" type="any";
	
	public any function getArgv() {
		return this.parseArgs();
	}

	public any function init(args,cwd) {
		var self = this;
	    
	    if (!cwd) cwd = request.cwd;
	    
	    self['$0'] = request.argv
	        .slice(0,2)
	        .map(function (x) {
	            var b = rebase(cwd, x);
	            return x.match(/^\//) && b.length < x.length
	                ? b : x
	        })
	        .join(' ');
	    
	    if (process.argv[1] == process.env._) {
	        self.$0 = process.env._.replace(
	            path.dirname(process.execPath) + '/', ''
	        );
	    }
	    
	    var flags = { bools : {}, strings : {} };
	    
	    self['boolean'] = function (bools) {
	        if (!Array.isArray(bools)) {
	            bools = [].slice.call(arguments);
	        }
	        
	        bools.forEach(function (name) {
	            flags.bools[name] = true;
	        });
	        
	        return self;
	    };
	    
	    self['string'] = function (strings) {
	        if (!Array.isArray(strings)) {
	            strings = [].slice.call(arguments);
	        }
	        
	        strings.forEach(function (name) {
	            flags.strings[name] = true;
	        });
	        
	        return self;
	    };
	    
	    var aliases = {};
	    self['alias'] = function (x, y) {
	        if (typeof x === 'object') {
	            structKeyArray(x).forEach(function (key) {
	                self.alias(key, x[key]);
	            });
	        }
	        else if (Array.isArray(y)) {
	            y.forEach(function (yy) {
	                self.alias(x, yy);
	            });
	        }
	        else {
	            var zs = (aliases[x] || []).concat(aliases[y] || []).concat(x, y);
	            aliases[x] = zs.filter(function (z) { return z != x });
	            aliases[y] = zs.filter(function (z) { return z != y });
	        }
	        
	        return self;
	    };
	    
	    var demanded = {};
	    self['demand'] = function (keys) {
	        if (typeof keys == 'number') {
	            if (!demanded._) demanded._ = 0;
	            demanded._ += keys;
	        }
	        else if (Array.isArray(keys)) {
	            keys.forEach(function (key) {
	                self.demand(key);
	            });
	        }
	        else {
	            demanded[keys] = true;
	        }
	        
	        return self;
	    };
	    
	    var usage;
	    self['usage'] = function (msg, opts) {
	        if (!opts && typeof msg === 'object') {
	            opts = msg;
	            msg = null;
	        }
	        
	        usage = msg;
	        
	        if (opts) self.options(opts);
	        
	        return self;
	    };
	    
	    var fail = function(msg) {
	        self.showHelp();
	        if (msg) console.error(msg);
	        process.exit(1);
	    }
	    
	    var checks = [];
	    self['check'] = function (f) {
	        checks.push(f);
	        return self;
	    };
	    
	    var defaults = {};
	    self['default'] = function (key, value) {
	        if (typeof key === 'object') {
	            structKeyArray(key).forEach(function (k) {
	                self.default(k, key[k]);
	            });
	        }
	        else {
	            defaults[key] = value;
	        }
	        
	        return self;
	    };
	    
	    var descriptions = {};
	    self['describe'] = function (key, desc) {
	        if (typeof key === 'object') {
	            structKeyArray(key).forEach(function (k) {
	                self.describe(k, key[k]);
	            });
	        }
	        else {
	            descriptions[key] = desc;
	        }
	        return self;
	    };
	    
	    self['parse'] = function (args) {
	        return Argv(args).argv;
	    };
	    
	    self['option'] = self['options'] = function (key, opt) {
	        if (typeof key === 'object') {
	            structKeyArray(key).forEach(function (k) {
	                self.options(k, key[k]);
	            });
	        }
	        else {
	            if (opt.alias) self.alias(key, opt.alias);
	            if (opt.demand) self.demand(key);
	            if (typeof opt.default !== 'undefined') {
	                self.default(key, opt.default);
	            }
	            
	            if (opt.boolean || opt.type === 'boolean') {
	                self.boolean(key);
	            }
	            if (opt.string || opt.type === 'string') {
	                self.string(key);
	            }
	            
	            var desc = opt.describe || opt.description || opt.desc;
	            if (desc) {
	                self.describe(key, desc);
	            }
	        }
	        
	        return self;
	    };
	    
	    var wrap = null;
	    self['wrap'] = function (cols) {
	        wrap = cols;
	        return self;
	    };
	    
	    self['showHelp'] = function (fn) {
	        if (!fn) fn = console.error;
	        fn(self.help());
	    };
	    
	    self['help'] = function () {
	        var keys = structKeyArray(
	            structKeyArray(descriptions)
	            .concat(structKeyArray(demanded))
	            .concat(structKeyArray(defaults))
	            .reduce(function (acc, key) {
	                if (key !== '_') acc[key] = true;
	                return acc;
	            }, {})
	        );
	        
	        var help = keys.length ? [ 'Options:' ] : [];
	        
	        if (usage) {
	            help.unshift(usage.replace(/\$0/g, self['$0']), '');
	        }
	        
	        var switches = keys.reduce(function (acc, key) {
	            acc[key] = [ key ].concat(aliases[key] || [])
	                .map(function (sw) {
	                    return (sw.length > 1 ? '--' : '-') + sw
	                })
	                .join(', ')
	            ;
	            return acc;
	        }, {});
	        
	        var switchlen = longest(structKeyArray(switches).map(function (s) {
	            return switches[s] || '';
	        }));
	        
	        var desclen = longest(structKeyArray(descriptions).map(function (d) { 
	            return descriptions[d] || '';
	        }));
	        
	        keys.forEach(function (key) {
	            var kswitch = switches[key];
	            var desc = descriptions[key] || '';
	            
	            if (wrap) {
	                desc = wordwrap(switchlen + 4, wrap)(desc)
	                    .slice(switchlen + 4)
	                ;
	            }
	            
	            var spadding = new Array(
	                Math.max(switchlen - kswitch.length + 3, 0)
	            ).join(' ');
	            
	            var dpadding = new Array(
	                Math.max(desclen - desc.length + 1, 0)
	            ).join(' ');
	            
	            var type = null;
	            
	            if (flags.bools[key]) type = '[boolean]';
	            if (flags.strings[key]) type = '[string]';
	            
	            if (!wrap && dpadding.length > 0) {
	                desc += dpadding;
	            }
	            
	            var prelude = '  ' + kswitch + spadding;
	            var extra = [
	                type,
	                demanded[key]
	                    ? '[required]'
	                    : null
	                ,
	                defaults[key] !== undefined
	                    ? '[default: ' + JSON.stringify(defaults[key]) + ']'
	                    : null
	                ,
	            ].filter(Boolean).join('  ');
	            
	            var body = [ desc, extra ].filter(Boolean).join('  ');
	            
	            if (wrap) {
	                var dlines = desc.split('\n');
	                var dlen = dlines.slice(-1)[0].length
	                    + (dlines.length === 1 ? prelude.length : 0)
	                
	                body = desc + (dlen + extra.length > wrap - 2
	                    ? '\n'
	                        + new Array(wrap - extra.length + 1).join(' ')
	                        + extra
	                    : new Array(wrap - extra.length - dlen + 1).join(' ')
	                        + extra
	                );
	            }
	            
	            help.push(prelude + body);
	        });
	        
	        help.push('');
	        return help.join('\n');
	    };
	    
	    
	    
	    
	    
	    return this;
	}

	public any function longest(xs) {
        return Math.max.apply(
            null,
            xs.map(function (x) { return x.length })
        );
    }

	public any function parseArgs() {
        var argv = { _ : [], $0 : self.$0 };
        structKeyArray(flags.bools).forEach(function (key) {
            setArg(key, defaults[key] || false);
        });
        
        function setArg (key, val) {
            var num = Number(val);
            var value = typeof val !== 'string' || isNaN(num) ? val : num;
            if (flags.strings[key]) value = val;
            
            setKey(argv, key.split('.'), value);
            
            (aliases[key] || []).forEach(function (x) {
                argv[x] = argv[key];
            });
        }
        
        for (var i = 0; i < args.length; i++) {
            var arg = args[i];
            
            if (arg === '--') {
                argv._.push.apply(argv._, args.slice(i + 1));
                break;
            }
            else if (arg.match(/^--.+=/)) {
                var m = arg.match(/^--([^=]+)=(.*)/);
                setArg(m[1], m[2]);
            }
            else if (arg.match(/^--no-.+/)) {
                var key = arg.match(/^--no-(.+)/)[1];
                setArg(key, false);
            }
            else if (arg.match(/^--.+/)) {
                var key = arg.match(/^--(.+)/)[1];
                var next = args[i + 1];
                if (next !== undefined && !next.match(/^-/)
                && !flags.bools[key]
                && (aliases[key] ? !flags.bools[aliases[key]] : true)) {
                    setArg(key, next);
                    i++;
                }
                else if (/^(true|false)$/.test(next)) {
                    setArg(key, next === 'true');
                    i++;
                }
                else {
                    setArg(key, true);
                }
            }
            else if (arg.match(/^-[^-]+/)) {
                var letters = arg.slice(1,-1).split('');
                
                var broken = false;
                for (var j = 0; j < letters.length; j++) {
                    if (letters[j+1] && letters[j+1].match(/\W/)) {
                        setArg(letters[j], arg.slice(j+2));
                        broken = true;
                        break;
                    }
                    else {
                        setArg(letters[j], true);
                    }
                }
                
                if (!broken) {
                    var key = arg.slice(-1)[0];
                    
                    if (args[i+1] && !args[i+1].match(/^-/)
                    && !flags.bools[key]
                    && (aliases[key] ? !flags.bools[aliases[key]] : true)) {
                        setArg(key, args[i+1]);
                        i++;
                    }
                    else if (args[i+1] && /true|false/.test(args[i+1])) {
                        setArg(key, args[i+1] === 'true');
                        i++;
                    }
                    else {
                        setArg(key, true);
                    }
                }
            }
            else {
                var n = Number(arg);
                argv._.push(flags.strings['_'] || isNaN(n) ? arg : n);
            }
        }
        
        _.forEach(structKeyArray(defaults),function (key) {
            if (!(key in argv)) {
                argv[key] = defaults[key];
                if (key in aliases) {
                    argv[aliases[key]] = defaults[key];
                }
            }
        },self);
        
        if (demanded._ && argv._.length < demanded._) {
            fail('Not enough non-option arguments: got '
                + argv._.length + ', need at least ' + demanded._
            );
        }
        
        var missing = [];
        structKeyArray(demanded).forEach(function (key) {
            if (!argv[key]) missing.push(key);
        });
        
        if (missing.length) {
            fail('Missing required arguments: ' + missing.join(', '));
        }
        
        checks.forEach(function (f) {
            try {
                if (f(argv) === false) {
                    fail('Argument check failed: ' + f.toString());
                }
            }
            catch (err) {
                fail(err)
            }
        });
        
        return argv;
    }
}