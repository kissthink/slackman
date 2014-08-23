Simple SBo manager. Features:
- Fakeroot to build packages without root access
- Muli-threaded builds
- Silent output, only errors are displayed
- Integrity checking with gpg, md5sum, umask
- Check SBo dependencies

Most of these are optional.

**Usage**

Slackman is controlled with the following environment variables: 
- *FROOT SBO_VER TMP OUTPUT CORE LOG*

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

Verbose output
