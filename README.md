Simple SBo manager. Features:
- Fakeroot to build packages without root access
- Muli-threaded builds
- Silent output, only errors are displayed
- Integrity checking with gpg, md5sum, umask
- Check SBo dependencies

Most of these are optional.

##Usage

Slackman is controlled with the following environment variables: 
- *FROOT* {0,1} Enable/disable fakeroot. Disabled if run as root.
- *SBO_VER* {11.0..14.1} Slackware version
- *TMP* Build folder
- *OUTPUT* Package folder
- *CORE* {1..99} Amount of CPU threads
- *LOG* {0,1} Enable/disable logs

Examples:

```
$ slackman <package>/<category>
```

Specify a category and package name to build. If unspecified, slackman asks for the package name.

```
$ CORE=16 slackman
```

Build with 16 threads (default: 2)

```
$ LOG=0 slackman
```

Log all output to stdout
