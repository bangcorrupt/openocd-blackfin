#!/bin/sh
#
# This scripts adds local version information from the version
# control systems git, mercurial (hg) and subversion (svn).
#
# Copied from Linux 2.6.32 scripts/setlocalversion and modified
# slightly to work better for OpenOCD.
#

usage() {
	echo "Usage: $0 [srctree]" >&2
	exit 1
}

cd "${1:-.}" || usage

# If there is a file named as "git-rev", just use the revision
# in that file.
if [ -e git-rev ]; then
	awk '{printf $0}' git-rev
	exit
fi

# Check for git and a git repo.
if head=`git rev-parse --verify --short HEAD 2>/dev/null`; then

	# If we are at a tagged commit (like "v2.6.30-rc6"), we ignore it,
	# because this version is defined in the top level Makefile.
	if [ -z "`git describe --exact-match 2>/dev/null`" ]; then

		# If we are past a tagged commit (like "v2.6.30-rc5-302-g72357d5"),
		# we pretty print it.
		if atag="`git describe 2>/dev/null`"; then
			echo "$atag" | awk -F- '{printf("-%s", $(NF))}'

		# If we don't have a tag at all we print -g{commitish}.
		else
			printf '%s%s' -g $head
		fi
	fi

	# Is this git on svn?
	if git config --get svn-remote.svn.url >/dev/null; then
	        printf -- '-svn%s' "`git svn find-rev $head`"
	fi

	# Update index only on r/w media
	[ -w . ] && git update-index --refresh --unmerged > /dev/null

	# Check for uncommitted changes
	if git diff-index --name-only HEAD | grep -v "^scripts/package" \
	    | read dummy; then
		printf '%s' -dirty
	fi

	# All done with git
	exit
fi

# Check for mercurial and a mercurial repo.
if hgid=`hg id 2>/dev/null`; then
	tag=`printf '%s' "$hgid" | cut -d' ' -f2`

	# Do we have an untagged version?
	if [ -z "$tag" -o "$tag" = tip ]; then
		id=`printf '%s' "$hgid" | sed 's/[+ ].*//'`
		printf '%s%s' -hg "$id"
	fi

	# Are there uncommitted changes?
	# These are represented by + after the changeset id.
	case "$hgid" in
		*+|*+\ *) printf '%s' -dirty ;;
	esac

	# All done with mercurial
	exit
fi

# Check for svn and a svn repo.
if rev=`svn info 2>/dev/null | grep '^Last Changed Rev'`; then
	rev=`echo $rev | awk '{print $NF}'`
	printf -- '-svn%s' "$rev"

	# All done with svn
	exit
fi

# There's no reecognized repository; we must be a snapshot.
printf -- '-snapshot'
