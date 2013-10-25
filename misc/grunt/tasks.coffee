# Path variables
finalBuildPath = "lib/"
componentFile  = "bower.json"

child   = require "child_process"

GIT_TAG       = "git describe --tags --abbrev=0"
CHANGELOG     = "coffee ./changelog.coffee"
VERSION_REGEX = /^v\d+\.\d+\.\d+$/

getLastVersion = (callback) ->
  child.exec GIT_TAG, (error, stdout, stderr) ->
    data = if error? then "" else stdout.replace("\n", "")
    callback error, data

module.exports = (grunt) ->

  # Replace templateUrl with actual html
  grunt.registerMultiTask "replace", "Replace placeholder with contents", ->
    options = @options
      separator: ""
      replace:   ""
      pattern:   null

    parse = (code) ->
      templateUrlRegex = options.pattern
      updatedCode      = code

      while match = templateUrlRegex.exec code
        if grunt.util._(options.replace).isFunction()
          replacement = options.replace match
        else
          replacement = options.replace

        updatedCode = updatedCode.replace match[0], replacement

      return updatedCode

    @files.forEach (file) ->
      src = file.src.filter (filepath) ->
        unless (exists = grunt.file.exists(filepath))
          grunt.log.warn "Source file '#{filepath}' not found"
        return exists
      .map (filepath) ->
        parse grunt.file.read(filepath)
      .join grunt.util.normalizelf(options.separator)

      grunt.file.write file.dest, src
      grunt.log.writeln("Replace placeholder with contents in '#{file.dest}' successfully")

  grunt.registerMultiTask "marked", "Convert markdown to html", ->
    options = @options
      separator: grunt.util.linefeed

    @files.forEach (file) ->
      src = file.src.filter (filepath) ->
        unless (exists = grunt.file.exists(filepath))
          grunt.log.warn "Source file '#{filepath}' not found"
        return exists
      .map (filepath) ->
        marked = require "marked"
        marked grunt.file.read(filepath)
      .join grunt.util.normalizelf(options.separator)

      grunt.file.write file.dest, src
      grunt.log.writeln("Converted '#{file.dest}'")

  # Read all files in build folder and add to component.json
  grunt.registerTask "update:component", "Update bower.json", ->
    fileList = []
    grunt.file.recurse finalBuildPath, (path, root, sub, filename) ->
      fileList.push path if filename.indexOf(".DS_Store") is -1

    data         = grunt.file.readJSON componentFile, encoding: "utf8"
    data.main    = fileList
    data.name    = grunt.config.get("pkg").name
    data.version = grunt.config.get("pkg").version

    grunt.file.write componentFile, JSON.stringify(data, null, "  "), encoding: "utf8"
    grunt.log.writeln "Updated bower.json"

  grunt.registerTask "bump", "Bump package version up and generate changelog", ->
    done = @async()

    version = grunt.option "tag"
    if version? and not VERSION_REGEX.test version
      grunt.fail.fatal "Invalid tag"

    if version?
      grunt.log.writeln version
    else
      getLastVersion (error, data) ->
        grunt.fail.fatal "Failed to read last tag" if error?

        grunt.log.writeln "Previous version #{data}"

        versionArr    = data.split "."
        versionArr[2] = +versionArr[2] + 1
        data          = versionArr.join "."

        grunt.log.writeln "Updating to version #{data}"

        pkg         = grunt.config.get("pkg")
        pkg.version = data[1..]
        grunt.file.write "package.json", JSON.stringify(pkg, null, "  "), encoding: "utf8"

        grunt.task.run "changelog"

        done()

  grunt.registerTask "changelog", "Generate temporary changelog", ->
    done    = @async()
    version = grunt.config.get("pkg").version

    CMD = "#{CHANGELOG} v#{version} changelog.tmp.md"
    child.exec CMD, (error, stdout, stderr) ->
      grunt.fail.fatal error if error?

      grunt.log.writeln stdout
      done()

  grunt.registerTask "tag", "Tag latest commit", ->
    done    = @async()
    version = grunt.config.get("pkg").version

    CMD = [
      "git commit -am 'chore(build): Build v#{version}'"
      "git tag v#{version}"
    ].join "&&"

    child.exec CMD, (error, stdout, stderr) ->
      grunt.fail.fatal "Failed to tag" if error?
      grunt.log.writeln stdout
      done()
