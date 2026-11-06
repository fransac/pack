PACK(5)

# NAME

pack - package repository

# DESCRIPTION

Each directory of a package repository may represent a package, as long as it contains 
the following mandatory files.

- _build_
- _outs_

Each package directory may also contain the following optional files.

- _depends_
- _sources_

The program chroots in a temporary directory before building a package; it is
initialized  with a "/src" directory. The directory may be accessed by the
program without a chroot, under certain conditions.

# PACKAGE FILES

_build_
	The _build_ file is an executable which, during the package installation, is
	copied  to "/src/build", relatively to the temporary directory, and called from
	it.

	Its duty is to build the package and install all of the files listed in _outs_
	to the temporary directory.

_outs_
	Each line of the _outs_ file must be the absolute path of each file to be
	installed.

	Lines that do not contain an absolute path are ignored.

	On the package uninstallation, all of the listed files are removed from the
	system. A package is only considered installed if all of the listed files
	exist.

	On the package installation, if the first line of the _outs_ file is
	"#no-chroot", the program will not chroot to the temporary directory; it will
	just run the _build_ file form the temporaryr directory. The "PREFIX" environment 
	variable will be set to the path of the temporary directory.

	Since this is potentially unsafe, the user is prompted before installing it.

_depends_
	The _depends_ file is a multi-line tab-separeted list of the following format.

		_PACKAGE_	[runtime]

	A valid _PACKAGE_ is the name of a package in the repository.

	Lines containing non-existent package names will be ignored.

	When "runtime" is present in the second column, _PACKAGE_ gets installed to the
	same directory the dependant package is installed to. Otherwise, _PACKAGE_ gets
	installed  to the temporary directory the dependant package is built in, before
	it is built.

_sources_
	The _sources_ file is a multi-line tab-separeted list of the following format.

		_SHA256_	_URL_	[_RELPATH_]

	Lines not containing all of the required fields are ignored.

	A valid _URL_ is the relative path to a file in the package directory, or a
	HTTP/HTTPS/FTP/FTPS address.

	If _URL_ is a local file, it must not be a directory.

	Each source must have a corresponding _SHA256_ hash.

	An optional _RELPATH_ field may be provided; it is the path, relative to "/src",
	where the fetched source file is moved to after being retrieved and checked.
