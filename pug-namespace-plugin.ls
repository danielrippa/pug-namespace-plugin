
  path = require 'path'
  livescript = process.main-module.require 'livescript'

  is-version = (part) ->

    pieces = part.split '.'
    return no unless pieces.length is 3

    for piece in pieces

      return no unless piece

      for character in piece
        return no if character < '0' or character > '9'

    yes

  qualified-name = (filename) ->

    parts = (path.resolve filename).split path.sep
    version = -1

    for part, index in parts
      version = index if is-version part

    if version < 0 or (path.extname filename).to-lower-case! isnt '.ls'
      throw new Error "Expected a versioned .ls module: #filename"

    name = parts.slice(version + 1).join '.'
    name.slice 0, -3

  import-name = (line) ->

    stripped = line.trim!
    return null unless (stripped.char-at 0) is '{' or (stripped.char-at 0) is '}'

    close-brace = line.last-index-of '}'
    return null if close-brace < 0

    rest = line.slice(close-brace + 1).trim!
    return null unless (rest.char-at 0) is '='

    rest = rest.slice(1).trim!
    return null unless (rest.slice 0, 10) is 'dependency'

    rest = rest.slice(10).trim!
    quote = rest.char-at 0
    return null unless quote is "'" or quote is '"'

    end = rest.index-of quote, 1
    return null if end < 0

    rest.slice 1, end

  named-source = (source, name) ->

    lines = source.split('\r\n').join('\n').split('\r').join('\n').split '\n'
    wrapper = no
    in-prelude = yes
    binding-block = no

    for line, index in lines

      stripped = line.trim!

      unless wrapper

        if stripped is 'do ->' or (stripped.slice -8) is ' = do ->'
          indentation = line.slice 0, line.length - stripped.length
          lines[index] = indentation + name + ' = do ->'
          wrapper = yes

        continue

      continue if not in-prelude or not stripped or (stripped.char-at 0) is '#'

      binding-block = yes if (stripped.char-at 0) is '{'
      imported = import-name line

      unless imported

        continue if binding-block
        in-prelude = no
        continue

      binding-block = no
      at = line.index-of 'dependency'
      quote-at = at + 10

      while (line.char-at quote-at) is ' ' or (line.char-at quote-at) is '\t'
        quote-at++

      quote = line.char-at quote-at
      quote-end = line.index-of quote, quote-at + 1
      lines[index] = line.slice(0, at) + imported + line.slice(quote-end + 1)

    throw new Error "No do -> wrapper for #name" unless wrapper

    lines.join '\n'

  namespace-lines = (name) ->

    parts = name.split '.'
    lines = []

    for index from 1 til parts.length

      prefix = parts.slice(0, index).join '.'
      declaration = if index is 1 then 'var ' else ''
      lines.push "#{declaration}#prefix = #prefix || {};"

    lines.join('\n') + '\n'

  exports.filters =

    namespace: (source, options) ->

      name = qualified-name options.filename
      compiled = livescript.compile (named-source source, name), bare: yes, header: no

      (namespace-lines name) + compiled
