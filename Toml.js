.pragma library

// A lossless document editor for the TOML value types used by Desktop AIO.
// Unsupported syntax is reported, never rewritten as an empty configuration.
function safe(key) {
  if (["__proto__", "prototype", "constructor", "__tomlRaw"].indexOf(key) >= 0)
    throw Error("Unsafe key: " + key);
  return key;
}
function split(s, delimiter) {
  var out = [], start = 0, quote = "", escaped = false, depth = 0;
  for (var i = 0; i < s.length; i++) {
    var c = s[i];
    if (quote) {
      if (escaped)
        escaped = false;
      else if (c === "\\" && quote === '"')
        escaped = true;
      else if (c === quote)
        quote = "";
    } else if (c === '"' || c === "'")
      quote = c;
    else if (c === "[" || c === "{")
      depth++;
    else if (c === "]" || c === "}")
      depth--;
    else if (c === delimiter && depth === 0) {
      out.push(s.slice(start, i).trim());
      start = i + 1;
    }
  }
  if (quote || depth !== 0)
    throw Error("Unclosed value");
  out.push(s.slice(start).trim());
  return out;
}
function keyPath(s) {
  return split(s, '.').map(function (k) {
    return safe(k[0] === '"' || k[0] === "'" ? value(k) : /^[A-Za-z0-9_-]+$/.test(k) ? k : (function () {
      throw Error("Invalid key: " + k);
    })());
  });
}
function value(v) {
  v = v.trim();
  if (v[0] === '"') {
    if (v.slice(0, 3) === '"""') {
      if (v.slice(-3) !== '"""')
        throw Error("Unclosed string");
      v = '"' + v.slice(3, -3).replace(/^\n/, '').replace(/\n/g, '\\n').replace(/\r/g, '\\r').replace(
            /(?<!\\)"/g, '\\"') + '"';
    }
    return JSON.parse(v.replace(/\\U([0-9a-fA-F]{8})/g, function (_, h) {
      return String.fromCodePoint(parseInt(h, 16));
    }));
  }
  if (v[0] === "'") {
    if (v.slice(0, 3) === "'''") {
      if (v.slice(-3) !== "'''")
        throw Error("Unclosed string");
      return v.slice(3, -3).replace(/^\n/, '');
    }
    if (v.length < 2 || v.slice(-1) !== "'")
      throw Error("Unclosed string");
    return v.slice(1, -1);
  }
  if (v === "true" || v === "false")
    return v === "true";
  if (v[0] === '[' && v.slice(-1) === ']')
    return split(v.slice(1, -1), ',').filter(function (x) {
      return x !== '';
    }).map(value);
  if (v[0] === '{' && v.slice(-1) === '}') {
    var o = {};
    split(v.slice(1, -1), ',').filter(function (x) {
      return x !== '';
    }).forEach(function (x) {
      var n = x.indexOf('=');
      if (n < 0)
        throw Error("Invalid inline table");
      put(o, keyPath(x.slice(0, n)), value(x.slice(n + 1)));
    });
    return o;
  }
  var n = v.replace(/_/g, '');
  if (/^[+-]?(?:\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|0x[\da-fA-F]+|0o[0-7]+|0b[01]+)$/.test(n) && isFinite(Number(
                                                                                                       n)))
    return Number(n);
  // Unknown date/time keys can round trip without turning into strings.
  if (/^\d{4}-\d\d-\d\d(?:[Tt ].*)?$/.test(v) || /^\d\d:\d\d:\d\d/.test(v))
    return {
      __tomlRaw: v
    };
  throw Error("Unsupported or invalid TOML value: " + v.slice(0, 80));
}
function get(o, path) {
  for (var i = 0; i < path.length; i++) {
    if (!o || typeof o !== 'object')
      return undefined;
    o = o[path[i]];
  }
  return o;
}
function put(o, path, v) {
  for (var i = 0; i < path.length - 1; i++) {
    var k = safe(path[i]);
    if (o[k] === undefined)
      o[k] = {};
    if (!o[k] || typeof o[k] !== 'object' || Array.isArray(o[k]))
      throw Error("Conflicting key: " + path.join('.'));
    o = o[k];
  }
  var last = safe(path[path.length - 1]);
  if (Object.prototype.hasOwnProperty.call(o, last))
    throw Error("Duplicate key: " + path.join('.'));
  o[last] = v;
}
function document(text) {
  text = String(text || '');
  if (text.length > 1048576)
    throw Error("Configuration exceeds 1 MiB");
  var data = {}, entries = [], headers = [], declared = {}, dotted = {}, section = [], offset = 0, lines
                                                                                                   = text.split(
                                                                                                     '\n');
  for (var i = 0; i < lines.length; i++) {
    var raw = lines[i], start = offset;
    offset += raw.length + 1;
    if (!raw.trim() || raw.trim()[0] === '#')
      continue;
    if (/^\s*\[/.test(raw)) {
      var header = raw.match(/^\s*\[([^\]]+)\]\s*(?:#.*)?$/);
      if (!header)
        throw Error("Invalid section on line " + (i + 1));
      section = keyPath(header[1]);
      var name = canonical(section);
      if (declared[name] || dotted[name])
        throw Error("Duplicate table: " + name);
      declared[name] = true;
      headers.push({
                     path: section.slice(),
                     end: offset
                   });
      continue;
    }
    var eq = -1, q = '', esc = false;
    for (var j = 0; j < raw.length; j++) {
      var c = raw[j];
      if (q) {
        if (esc)
          esc = false;
        else if (c === '\\' && q === '"')
          esc = true;
        else if (c === q)
          q = '';
      } else if (c === '"' || c === "'")
        q = c;
      else if (c === '=') {
        eq = j;
        break;
      }
    }
    if (eq < 0)
      throw Error("Expected key = value on line " + (i + 1));
    var path = section.concat(keyPath(raw.slice(0, eq))), source = raw.slice(eq + 1), clean = '', quote = '',
    triple = false, depth = 0, escaped = false, suffix = '';
    // Accumulate arrays and multiline strings, removing only comments outside strings.
    for (; ; ) {
      for (var z = 0; z < source.length; z++) {
        var ch = source[z];
        if (quote) {
          clean += ch;
          if (escaped) {
            escaped = false;
            continue;
          }
          if (ch === '\\' && quote === '"') {
            escaped = true;
            continue;
          }
          if (ch === quote) {
            if (!triple)
              quote = '';
            else if (source.slice(z, z + 3) === quote + quote + quote) {
              clean += source.slice(z + 1, z + 3);
              z += 2;
              quote = '';
              triple = false;
            }
          }
        } else if (ch === '"' || ch === "'") {
          quote = ch;
          triple = source.slice(z, z + 3) === ch + ch + ch;
          clean += triple ? source.slice(z, z + 3) : ch;
          if (triple)
            z += 2;
        } else if (ch === '#') {
          suffix = source.slice(z);
          break;
        } else {
          clean += ch;
          if (ch === '[' || ch === '{')
            depth++;
          if (ch === ']' || ch === '}')
            depth--;
        }
      }
      if (!quote && depth === 0)
        break;
      if (!triple && quote)
        throw Error("Unclosed string");
      i++;
      if (i >= lines.length)
        throw Error("Unclosed value");
      source = lines[i];
      offset += source.length + 1;
      clean += '\n';
    }
    for (var prefix = section.length + 1; prefix < path.length; prefix++)
      dotted[canonical(path.slice(0, prefix))] = true;
    var parsed = value(clean);
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed) && !parsed.__tomlRaw)
      dotted[canonical(path)] = true;
    put(data, path, parsed);
    entries.push({
                   path: path,
                   start: start,
                   end: offset - 1,
                   prefix: raw.slice(0, eq + 1) + ' ',
                   comment: suffix
                 });
  }
  return {
    data: data,
    entries: entries,
    headers: headers,
    text: text
  };
}
function parse(text) {
  return document(text).data;
}
function encode(v) {
  if (typeof v === 'string')
    return JSON.stringify(v);
  if (typeof v === 'boolean')
    return String(v);
  if (typeof v === 'number' && isFinite(v))
    return String(v);
  if (Array.isArray(v))
    return '[' + v.map(encode).join(', ') + ']';
  if (v && typeof v === 'object') {
    if (v.__tomlRaw)
      return v.__tomlRaw;
    return '{ ' + Object.keys(v).map(function (k) {
      return JSON.stringify(safe(k)) + ' = ' + encode(v[k]);
    }).join(', ') + ' }';
  }
  throw Error("Value cannot be serialized");
}
function canonical(path) {
  return path.map(function (k) {
    safe(k);
    return /^[A-Za-z0-9_-]+$/.test(k) ? k : JSON.stringify(k);
  }).join(".");
}
function flatten(o, prefix) {
  var out = {};
  Object.keys(o).forEach(function (k) {
    var p = (prefix ? prefix + '.' : '') + canonical([k]), v = o[k];
    if (v && typeof v === 'object' && !Array.isArray(v) && !v.__tomlRaw)
      Object.assign(out, flatten(v, p));
    else
      out[p] = v;
  });
  return out;
}
function assign(o, path, v) {
  for (var i = 0; i < path.length - 1; i++) {
    safe(path[i]);
    if (!o[path[i]] || typeof o[path[i]] !== 'object')
      o[path[i]] = {};
    o = o[path[i]];
  }
  var key = safe(path[path.length - 1]);
  if (v === undefined)
    delete o[key];
  else
    o[key] = v;
}
function patch(text, changes) {
  var doc = document(text), edits = [], remaining = Object.assign({}, changes);
  doc.entries.forEach(function (e) {
    var key = canonical(e.path), v, changed = false;
    if (Object.prototype.hasOwnProperty.call(remaining, key)) {
      v = remaining[key];
      delete remaining[key];
      changed = true;
    } else {
      var children = Object.keys(remaining).filter(function (k) {
        return k.indexOf(key + '.') === 0;
      });
      if (children.length) {
        v = JSON.parse(JSON.stringify(get(doc.data, e.path)));
        children.forEach(function (k) {
          assign(v, keyPath(k.slice(key.length + 1)), remaining[k]);
          delete remaining[k];
        });
        changed = true;
      }
    }
    if (changed)
      edits.push({
                   start: e.start,
                   end: e.end,
                   text: v === undefined ? (e.comment || '') : e.prefix + encode(v) + (e.comment ? ' '
                                                                                                   + e.comment :
                                                                                                   '')
                 });
  });
  var insertions = {};
  Object.keys(remaining).forEach(function (key) {
    if (remaining[key] === undefined)
      return;
    var parts = keyPath(key), best = null;
    doc.headers.forEach(function (h) {
      if (h.path.length < parts.length && h.path.every(function (k, i) {
        return k === parts[i];
      }) && (!best || h.path.length > best.path.length))
        best = h;
    });
    var offset = best ? best.end : 0, tail = best ? parts.slice(best.path.length) : parts;
    var line = tail.map(function (k) {
      return JSON.stringify(safe(k));
    }).join('.') + ' = ' + encode(remaining[key]) + '\n';
    insertions[offset] = (insertions[offset] || '') + line;
  });
  Object.keys(insertions).forEach(function (offset) {
    var n = Number(offset), prefix = n > 0 && text[n - 1] !== '\n' ? '\n' : '';
    edits.push({
                 start: n,
                 end: n,
                 text: prefix + insertions[offset]
               });
  });
  edits.sort(function (a, b) {
    return b.start - a.start;
  }).forEach(function (e) {
    text = text.slice(0, e.start) + e.text + text.slice(e.end);
  });
  parse(text);
  return text;
}
function merge(base, overrides) {
  var out = JSON.parse(JSON.stringify(base));
  Object.keys(overrides).forEach(function (k) {
    var v = overrides[k];
    if (v && typeof v === 'object' && !Array.isArray(v) && !v.__tomlRaw)
      out[k] = merge(out[k] || {}, v);
    else
      out[k] = v;
  });
  return out;
}
