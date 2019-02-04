[Platform::] POSIX Platforms.

A version of our operating system interface suitable for POSIX-compliant
operating systems.

@ The C standard library leaves many questions unanswered about how to deal
with the host operating system: for example, it knows very little about
directories, or about concurrency. The POSIX standard ("Portable Operating
System Interface") aims to fill these gaps by providing facilities which
ought to exist across any Unix-like system. POSIX is neither fully present
on Unix-like systems nor fully absent from Windows, but for the limited
purposes we need here, it's simplest to divide all operating systems into
two groups: the POSIX group, and Windows.

This Foundation module therefore comes with two variant versions of the
|Platform::| section of code. The one you're reading compiles on a POSIX
operating system, and the other one on Windows.

@ Some basics that apply to all POSIX-supporting systems.

@d FOLDER_SEPARATOR '/'
@d SHELL_QUOTE_CHARACTER '\''

= (very early code)
#include <sys/stat.h>
#include <sys/types.h>
#include <errno.h>
#include <dirent.h>
#include <pthread.h>
#include <limits.h>
#include <unistd.h>

@h Mac OS X. ^"ifdef-PLATFORM_MACOSX"

@d PLATFORM_STRING "macos"
@d SHELL_QUOTE_CHARACTER '\''
@d INFORM_FOLDER_RELATIVE_TO_HOME "Library"

@h Generic Unix. ^"ifdef-PLATFORM_UNIX"
These settings are used both for the Linux versions (both command-line, by
Adam Thornton, and for Ubuntu, Fedora, Debian and so forth, by Philip
Chimento) and also for Solaris variants: they can probably be used for any
Unix-based system.

@d PLATFORM_STRING "unix"
@d INFORM_FOLDER_RELATIVE_TO_HOME ""

= (very early code)
#include <strings.h>

@h Linux. ^"ifdef-PLATFORM_LINUX"
These settings are used both for the Linux versions (both command-line, by
Adam Thornton, and for Ubuntu, Fedora, Debian and so forth, by Philip
Chimento) and also for Solaris variants: they can probably be used for any
Unix-based system.

@d PLATFORM_STRING "linux"
@d INFORM_FOLDER_RELATIVE_TO_HOME ""

= (very early code)
#include <strings.h>

@h Android. ^"ifdef-PLATFORM_ANDROID"
These settings are used for Nathan Summers's Android versions.

@d PLATFORM_STRING "android"
@d SUPPRESS_MAIN
@d INFORM_FOLDER_RELATIVE_TO_HOME ""

= (very early code)
#include <strings.h>

@h Locale.
The following definition handles possible differences of text encoding
in filenames, which depend on the current "locale". Locale is an odd piece
of old Unix terminology, but one thing it includes is how the textual names
of files are encoded (as ASCII, as ISO Latin-1, as UTF-8, etc.). The default
here is UTF-8 since OS X and Linux both adopt this.

=
#ifndef LOCALE_IS_ISO
#ifndef LOCALE_IS_UTF8
#define LOCALE_IS_UTF8 1
#endif
#endif

@h Environment variables.

=
char *Platform::getenv(const char *name) {
	return getenv(name);
}

@h Executable location. ^"ifdef-PLATFORM_LINUX"
Fill the wide-char buffer |p| with the path to the current executable, up to
length |length|. This function is guaranteed to be called from only one
thread. Should the information be unavailable, or fail to fit into |p|,
truncate |p| to zero length. (On some platforms, the information will
always be unavailable: that doesn't mean we can't run on those platforms,
just that installation and use of Foundation-built tools is less convenient.)

=
void Platform::where_am_i(wchar_t *p, size_t length) {
    char buffer[PATH_MAX + 1];
    @<Follow the proc filesystem symlink to the real filesystem's file@>;
	@<Transcode buffer, which is locale-encoded, into the wide-char buffer@>;
}

@ On Linux, |/proc/self/exe| is a symlink to the current process's executable.
Follow that link to find the path. Normally when reading a symlink, one uses
|lstat()| to find the path length instead of guessing |PATH_MAX|, but the
symlinks in |/proc| are special and don't provide a length to |lstat()|.

@<Follow the proc filesystem symlink to the real filesystem's file@> =
	ssize_t link_len = readlink("/proc/self/exe", buffer, PATH_MAX);
    if (link_len < 0) @<Fail@>; // unable to find
    buffer[link_len] = '\0';

@ Next, convert the obtained buffer (which is a string in the local filename
encoding, and possibly in a multibyte encoding such as UTF-8) to a wide-char
string.

@<Transcode buffer, which is locale-encoded, into the wide-char buffer@> =
    size_t convert_len = mbstowcs(p, buffer, length);
    if (convert_len == (size_t)-1) @<Fail@>; // wouldn't fit

@<Fail@> =
	p[0] = '\0';
	return;

@h Executable location. ^"ifndef-PLATFORM_LINUX"
 
=
void Platform::where_am_i(wchar_t *p, size_t length) {
	p[0] = 0;
}

@h Shell commands.

=
int Platform::system(const char *cmd) {
	return system(cmd);
}

@h Directory handling.

=
int Platform::mkdir(char *transcoded_pathname) {
	errno = 0;
	int rv = mkdir(transcoded_pathname, S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH);
	if (rv == 0) return TRUE;
	if (errno == EEXIST) return TRUE;
	return FALSE;
}

void *Platform::opendir(char *path_to_folder) {
	DIR *dirp = opendir(path_to_folder);
	return (void *) dirp;
}

int Platform::readdir(void *folder, char *path_to_folder, char *leafname) {
	char path_to[2*MAX_FILENAME_LENGTH+2];
	struct stat file_status;
	int rv;
	DIR *dirp = (DIR *) folder;
	struct dirent *dp;
	if ((dp = readdir(dirp)) == NULL) return FALSE;
	sprintf(path_to, "%s%c%s", path_to_folder, FOLDER_SEPARATOR, dp->d_name);
	rv = stat(path_to, &file_status);
	if (rv != 0) return FALSE;
	if (S_ISDIR(file_status.st_mode)) sprintf(leafname, "%s/", dp->d_name);
	else strcpy(leafname, dp->d_name);
	return TRUE;
}

void Platform::closedir(void *folder) {
	DIR *dirp = (DIR *) folder;
	closedir(dirp);
}

@h Sleep.

=
void Platform::sleep(int seconds) {
	sleep((unsigned int) seconds);
}

@h Notifications. ^"ifdef-PLATFORM_MACOSX"
The "submarine" sound is a gloomy thunk; the "bell" is the three-tone rising
alert noise which iPhones make when they receive texts, but which hackers of a
certain age will remember as the "I have ripped your music CD now" alert from
SoundJam, the program which Apple bought and rebranded as iTunes. Apple now
seems to consider this alert a general-purpose "something good has happened".

It is anybody's guess how long Apple will permit the shell command |osascript|
to survive, given the MacOS team's current hostility to scripting; we're
actually running a one-line AppleScript here.

=
void Platform::notification(text_stream *text, int happy) {
	char *sound_name = "Bell.aiff";
	if (happy == FALSE) sound_name = "Submarine.aiff";
	TEMPORARY_TEXT(TEMP)
	WRITE_TO(TEMP, "osascript -e 'display notification \"%S\" "
		"sound name \"%s\" with title \"intest Results\"'", text, sound_name);
	Shell::run(TEMP);
	DISCARD_TEXT(TEMP)
}

@ ^"ifndef-PLATFORM_MACOSX"

= 
void Platform::notification(text_stream *text, int happy) {
}

@h Concurrency.

= (very early code)
typedef pthread_t foundation_thread;
typedef pthread_attr_t foundation_thread_attributes;

@

=
int Platform::create_thread(foundation_thread *pt,
	const foundation_thread_attributes *pa, void *(*fn)(void *), void *arg) {
	return pthread_create(pt, pa, fn, arg);
}

int Platform::join_thread(pthread_t pt, void** rv) {
	return pthread_join(pt, rv);
}

void Platform::init_thread(pthread_attr_t* pa, size_t size) {
	pthread_attr_init(pa);
	pthread_attr_setstacksize(pa, size);
}

size_t Platform::get_thread_stack_size(pthread_attr_t* pa) {
	size_t mystacksize;
	pthread_attr_getstacksize(pa, &mystacksize);
	return mystacksize;
}

@h Mutexes.

@d CREATE_MUTEX(name)
	static pthread_mutex_t name = PTHREAD_MUTEX_INITIALIZER;
@d LOCK_MUTEX(name) pthread_mutex_lock(&name);
@d UNLOCK_MUTEX(name) pthread_mutex_unlock(&name);
