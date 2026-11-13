#import "Archive.h"
#include <sys/stat.h>

// libarchive ships in iOS (libarchive.tbd in the SDK) without headers
struct archive;
struct archive_entry;

#define ARCHIVE_EOF 1
#define ARCHIVE_OK 0
#define ARCHIVE_WARN (-20)

#define ARCHIVE_EXTRACT_TIME 0x0004
#define ARCHIVE_EXTRACT_SECURE_SYMLINKS 0x0100
#define ARCHIVE_EXTRACT_SECURE_NODOTDOT 0x0200

struct archive *archive_read_new(void);
int archive_read_support_format_all(struct archive *);
int archive_read_support_filter_all(struct archive *);
int archive_read_open_filename(struct archive *, const char *, size_t);
int archive_read_next_header(struct archive *, struct archive_entry **);
int archive_read_data_block(struct archive *, const void **, size_t *, int64_t *);
int archive_read_free(struct archive *);

struct archive *archive_write_new(void);
int archive_write_set_format_zip(struct archive *);
int archive_write_open_filename(struct archive *, const char *);
int archive_write_header(struct archive *, struct archive_entry *);
ssize_t archive_write_data(struct archive *, const void *, size_t);
int archive_write_close(struct archive *);
int archive_write_free(struct archive *);

struct archive *archive_write_disk_new(void);
int archive_write_disk_set_options(struct archive *, int);
ssize_t archive_write_data_block(struct archive *, const void *, size_t, int64_t);
int archive_write_finish_entry(struct archive *);

const char *archive_error_string(struct archive *);

struct archive_entry *archive_entry_new(void);
void archive_entry_free(struct archive_entry *);
const char *archive_entry_pathname(struct archive_entry *);
void archive_entry_copy_pathname(struct archive_entry *, const char *);
void archive_entry_copy_stat(struct archive_entry *, const struct stat *);
void archive_entry_copy_symlink(struct archive_entry *, const char *);

static NSString *errorOf(struct archive *a) {
    const char *message = archive_error_string(a);
    return message ? @(message) : @"unknown error";
}

static NSString *addEntry(struct archive *zip, NSString *path, NSString *name) {
    struct stat info;
    if (lstat(path.fileSystemRepresentation, &info) != 0) return @(strerror(errno));

    struct archive_entry *entry = archive_entry_new();
    archive_entry_copy_stat(entry, &info);
    archive_entry_copy_pathname(entry, name.fileSystemRepresentation);
    if (S_ISLNK(info.st_mode)) {
        NSString *target = [NSFileManager.defaultManager destinationOfSymbolicLinkAtPath:path error:nil];
        if (target) archive_entry_copy_symlink(entry, target.fileSystemRepresentation);
    }

    NSString *error = nil;
    if (archive_write_header(zip, entry) < ARCHIVE_WARN) {
        error = errorOf(zip);
    } else if (S_ISREG(info.st_mode)) {
        FILE *file = fopen(path.fileSystemRepresentation, "rb");
        if (!file) {
            error = @(strerror(errno));
        } else {
            char buffer[65536];
            size_t length;
            while ((length = fread(buffer, 1, sizeof(buffer), file)) > 0) {
                if (archive_write_data(zip, buffer, length) < 0) {
                    error = errorOf(zip);
                    break;
                }
            }
            fclose(file);
        }
    }
    archive_entry_free(entry);
    return error;
}

NSString *createZip(NSString *sourcePath, NSString *zipPath) {
    struct archive *zip = archive_write_new();
    archive_write_set_format_zip(zip);
    if (archive_write_open_filename(zip, zipPath.fileSystemRepresentation) != ARCHIVE_OK) {
        NSString *error = errorOf(zip);
        archive_write_free(zip);
        return error;
    }

    NSString *rootName = sourcePath.lastPathComponent;
    NSString *error = addEntry(zip, sourcePath, rootName);

    BOOL isDir = NO;
    [NSFileManager.defaultManager fileExistsAtPath:sourcePath isDirectory:&isDir];
    if (!error && isDir) {
        NSDirectoryEnumerator *enumerator = [NSFileManager.defaultManager enumeratorAtPath:sourcePath];
        for (NSString *relative in enumerator) {
            error = addEntry(zip, [sourcePath stringByAppendingPathComponent:relative],
                             [rootName stringByAppendingPathComponent:relative]);
            if (error) break;
        }
    }

    if (archive_write_close(zip) != ARCHIVE_OK && !error) error = errorOf(zip);
    archive_write_free(zip);
    if (error) [NSFileManager.defaultManager removeItemAtPath:zipPath error:nil];
    return error;
}

NSString *extractArchive(NSString *archivePath, NSString *destinationPath) {
    struct archive *reader = archive_read_new();
    archive_read_support_format_all(reader);
    archive_read_support_filter_all(reader);
    if (archive_read_open_filename(reader, archivePath.fileSystemRepresentation, 65536) != ARCHIVE_OK) {
        NSString *error = errorOf(reader);
        archive_read_free(reader);
        return error;
    }

    struct archive *writer = archive_write_disk_new();
    archive_write_disk_set_options(writer, ARCHIVE_EXTRACT_TIME
                                   | ARCHIVE_EXTRACT_SECURE_SYMLINKS
                                   | ARCHIVE_EXTRACT_SECURE_NODOTDOT);

    NSString *error = nil;
    struct archive_entry *entry;
    int status;
    while ((status = archive_read_next_header(reader, &entry)) != ARCHIVE_EOF) {
        if (status < ARCHIVE_WARN) {
            error = errorOf(reader);
            break;
        }
        NSString *name = @(archive_entry_pathname(entry));
        // Finder adds resource forks under __MACOSX
        if ([name hasPrefix:@"__MACOSX/"]) continue;
        // Entry names, absolute ones too, are placed under the destination
        archive_entry_copy_pathname(entry, [destinationPath stringByAppendingPathComponent:name].fileSystemRepresentation);
        if (archive_write_header(writer, entry) < ARCHIVE_WARN) {
            error = errorOf(writer);
            break;
        }
        const void *block;
        size_t size;
        int64_t offset;
        while ((status = archive_read_data_block(reader, &block, &size, &offset)) == ARCHIVE_OK) {
            if (archive_write_data_block(writer, block, size, offset) < ARCHIVE_WARN) {
                error = errorOf(writer);
                break;
            }
        }
        if (!error && status < ARCHIVE_WARN) error = errorOf(reader);
        if (error) break;
        archive_write_finish_entry(writer);
    }

    archive_read_free(reader);
    archive_write_free(writer);
    return error;
}
