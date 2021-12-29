#!/bin/env python3

import base64
import os
import re
import sys

from mutagen.flac import Picture
from mutagen.flac import error as FLACError
from mutagen.oggopus import OggOpus

illegal_fat_chars = re.compile("[\\?*|<:>]")
illegal_fat_ends = re.compile("[. ]+(/|$)")
dir_up = re.compile("(/|^)\\.\\.(?=(/|$))")
dir_same = re.compile("(/|^)\\.(?=(/|$))")


FFMPEG_LOG = "error"
FFMPEG_BITRATE = "60k"

COVER_BASENAME_SEARCH = "cover"
COVER_BASENAME_SAVE = "cover"
COVER_DIMENSION_INTERN = "400x400"
COVER_DIMENSION_EXTERN = "500x500"
COVER_SAVE_EXTERN_FILE = True
COVER_SAVE_IN_FILES = True
COVER_TYPE = ".jpg"

PROGRESS_TIME = True
PROGRESS_STEPS = True
PROGRESS_CONTENT = False
PROGRESS_PERCENT = True
PROGRESS_PERCENT_OF = "steps"


USE_FAT_NAMES = True
PRINT_PROGESS = True
DRY = False
KEEP_TRANSPARENCY = "y"  # ask, n

AUDIO_EXTENSIONS = [".mp3", ".flac", ".wma", ".wav", ".ogg", ".opus"]
COVER_EXTENSIONS = [".jpg", ".jpeg", ".png"]


def is_fat_fs(destination):
    global USE_FAT_NAMES
    filename = '\\?*|<:>"'
    while not os.path.exists(destination):
        destination = os.path.dirname(destination)

    filename = os.path.join(destination, filename)

    try:
        file_handler = open(filename, "a")
        if os.path.exists(filename):
            file_handler.close()
            os.remove(filename)
    except IOError:
        USE_FAT_NAMES = True
        print(
            "-> Destination is possibly on a FAT file system! Using long "
            + "FAT names."
        )


def is_terminal_connected():
    global PRINT_PROGESS
    try:
        _ = os.get_terminal_size().columns
    except OSError:
        PRINT_PROGESS = False


def to_target_name(file_name):
    if USE_FAT_NAMES:
        return re.sub(illegal_fat_chars, "_",
                      re.sub(illegal_fat_ends, "_\\1",
                             re.sub(dir_up, "\\1\0\0",
                                    re.sub(dir_same, "\\1\0", file_name))
                             .replace(": ", " - ").replace('"', "'"))).replace(
                                 "\0", ".")
    return file_name


def write_cover_opus(afile, cover):
    file_ = OggOpus(afile)

    with open(cover, "rb") as h:
        data = h.read()

    picture = Picture()
    picture.data = data
    picture.type = 17
    picture.desc = u"cover art"
    picture.mime = u"image/" + os.path.splitext(cover)[1][1:]
    dim = [int(x) for x in COVER_DIMENSION_INTERN.split("x")]
    picture.width = dim[0]
    picture.height = dim[1]
    picture.depth = 24

    picture_data = picture.write()
    encoded_data = base64.b64encode(picture_data)
    vcomment_value = encoded_data.decode("ascii")

    file_["metadata_block_picture"] = [vcomment_value]
    file_.save()


def filter_files(files, extensions, skip_hidden=True):
    ret = []
    for file in files:
        if skip_hidden and file.startswith("."):
            continue
        root, ext = os.path.splitext(file)
        extl = ext.lower()
        for test_ext in extensions:
            if test_ext == extl:
                ret.append((root, ext))
                break
    return ret


class Progress:
    def __init__(
        self,
        name="",
        current_step=None,
        total_steps=None,
        current_content=0,
        total_content=None,
        current_time=None,
        total_time=None,
        last_time=None,
    ):
        self.name = name
        self.current_step = current_step
        self.total_steps = total_steps
        self.current_content = current_content
        self.total_content = total_content
        self.current_time = current_time
        self.total_time = total_time
        self.last_time = last_time
        self.internal_counter = 0
        self.last_time_fmt = ""

    def update(
        self,
        current_step=None,
        total_steps=None,
        current_content=None,
        total_content=None,
        current_time=None,
        total_time=None,
        last_time=None,
    ):
        if current_step:
            self.current_step += current_step
        if total_steps:
            self.total_steps = total_steps
        if current_content:
            self.current_content += current_content
        if total_content:
            self.total_content = total_content
        if current_time:
            self.current_time += current_time
        if total_time:
            self.total_time = total_time
        if last_time:
            self.last_time = last_time

    @staticmethod
    def format_time(time):
        t = int(time)
        if t >= 3600:
            return "{:d}:{:02d}:{:02d}".format(t // 3600, t % 3600 // 60,
                                               t % 60)
        else:
            return "{:02d}:{:02d}".format(t // 60, t % 60)

    def get_etr_content(self, time_last_step, content_last_step):
        if content_last_step:
            remaining_time = (
                float(time_last_step)
                / content_last_step
                * float(self.total_content - self.current_content -
                        content_last_step)
            )
            self.last_time = time_last_step
            self.last_time_fmt = self.format_time(remaining_time)
        return self.last_time_fmt

    def get_bar(
        self,
        name_width=0,
        estimated_time_width=None,
        total_steps_width=None,
        total_content_width=None,
        percent_of="steps",
        show_percent=True,
    ):
        name_width = max(len(self.name), name_width)
        if self.total_steps and percent_of == "steps":
            percent = float(self.current_step) / self.total_steps
        elif self.total_content and percent_of == "content":
            percent = float(self.current_content) / self.total_content
        else:
            percent = None
        if percent and show_percent:
            totperc = "{:>3d}%".format(round(percent * 100))
        else:
            totperc = ""

        if estimated_time_width is not None and self.last_time_fmt:
            esttime = "{:>{width}}".format(
                self.last_time_fmt, width=estimated_time_width
            )
        else:
            esttime = ""

        if total_steps_width is not None and self.total_steps:
            totsteps = "{:>{width}d}/{:>{width}d}".format(
                self.current_step, self.total_steps, width=total_steps_width
            )
        else:
            totsteps = ""

        if total_content_width is not None and self.total_content:
            totcont = "{:>{width}d}/{:>{width}d}".format(
                self.current_content,
                self.total_content,
                width=total_content_width
            )
        else:
            totcont = ""

        prefix = "{name:<{n_w}}".format(name=self.name, n_w=name_width + 1)
        suffix = (
            ("{steps:>{s_w}}{content:>{c_w}}" +
             "{ert:>{e_w}}{percent:>{p_w}}").format(
                steps=totsteps,
                s_w=len(totsteps) + int(totsteps != ""),
                content=totcont,
                c_w=len(totcont) + int(totcont != ""),
                ert=esttime,
                e_w=len(esttime) + int(esttime != ""),
                percent=totperc,
                p_w=len(totperc) + int(totperc != ""),
            )
        )

        bar_length = os.get_terminal_size().columns
        bar_length -= len(prefix) + len(suffix) + 2  # 2 padding spaces
        if percent is not None:
            arrow = "=" * int(round(percent * bar_length)) +\
                    " " * (bar_length - int(round(percent * bar_length)))
        else:
            arrow = "==="
            max_space = bar_length - len(arrow)
            arrow = (
                " " * (
                    (self.internal_counter % max_space)
                    if self.internal_counter % (max_space * 2) - max_space < 0
                    else (max_space - self.internal_counter % max_space)
                )
                + arrow
            )
            arrow = "{:<{}}".format(arrow, bar_length)
            self.internal_counter += 1

        return "{:.{}}".format(
            prefix + "[" + arrow + "]" + suffix, os.get_terminal_size().columns
        )

    @staticmethod
    def print_progesses(progresses, last_time, last_content):
        from math import log

        max_nwidth = max([len(x.name) for x in progresses])
        max_cwidth = (
            max([int(log(x.total_content, 10)) + 1 for x in progresses])
            if PROGRESS_CONTENT
            else None
        )
        max_swidth = (
            max([int(log(x.total_steps, 10)) + 1 for x in progresses])
            if PROGRESS_STEPS
            else None
        )
        max_twidth = (
            max([len(x.get_etr_content(last_time, last_content))
                 for x in progresses])
            if PROGRESS_TIME
            else None
        )

        print("\r\033[" + str(len(progresses)) + "A", end="")
        for p in progresses:
            print(
                "\033[1B\r\033[2K"
                + p.get_bar(
                    max_nwidth,
                    max_twidth,
                    max_swidth,
                    max_cwidth,
                    PROGRESS_PERCENT_OF,
                    PROGRESS_PERCENT,
                ),
                end="",
            )

    @staticmethod
    def clear_progesses(progresses):
        for _ in range(len(progresses)):
            print("\r\033[2K\033[A", end="")
        print()


def convert_opus(files, source_dir, destination_dir, total_progress):
    ret = []
    import time

    import ffmpy

    if len(files) == 0:
        return ret
    size = 0
    if PRINT_PROGESS:
        print()
    for afile, ext in files:
        size += os.path.getsize(os.path.join(source_dir, afile + ext))
    dir_progress = Progress(
        name="Directory:",
        current_step=0,
        total_steps=len(files),
        current_content=0,
        total_content=size,
        current_time=0,
    )
    progresses = [dir_progress, total_progress]
    if PRINT_PROGESS:
        Progress.print_progesses(progresses, 0, 0)

    for afile, ext in files:
        infile = os.path.join(source_dir, afile + ext)
        outfile = to_target_name(
            os.path.join(destination_dir, afile + ".opus"))
        try:
            ff = ffmpy.FFmpeg(
                inputs={infile: "-y -v " + FFMPEG_LOG},  # Always overwrite!
                outputs={outfile: "-b:a " + FFMPEG_BITRATE},
            )
            t = time.time()
            if not DRY:
                ff.run()
            t = time.time() - t
            fsize = os.path.getsize(infile)
            total_progress.update(
                current_step=1, current_content=fsize, current_time=t,
                last_time=t
            )
            dir_progress.update(
                current_step=1, current_content=fsize, current_time=t,
                last_time=t
            )
            if PRINT_PROGESS:
                Progress.print_progesses(progresses, t, fsize)
            ret.append((infile, outfile))
        except FLACError as e:
            print("Error:" + infile)
            print(e)
        except ffmpy.FFRuntimeError as e:
            print("Error:" + infile)
            print(e)
    if PRINT_PROGESS:
        Progress.clear_progesses(progresses)
    return ret


def convert_cover(files, aud_files, source_dir, destination_dir):
    import subprocess

    import ffmpy

    if not COVER_SAVE_EXTERN_FILE and not COVER_SAVE_IN_FILES:
        return (None, None, None)
    if len(aud_files) == 0:
        return (None, None, None)  # Nothing to do

    print("Fetching cover in '{}'".format(source_dir))
    infile = None
    outfile_ext = None
    outfile_int = None
    outext = COVER_TYPE
    TMPFILE = "/tmp/tmpcover.png"

    for afile, ext in files:
        if afile.lower() == COVER_BASENAME_SEARCH:
            infile = os.path.join(source_dir, afile + ext)
            break
    else:
        print("-> No cover.* found in '{}'".format(source_dir))
        f, ex = aud_files[0]  # Just get the first file
        tmpinf = os.path.join(source_dir, f + ex)
        print(
            f"   Trying to fetch it from the audio files... (using '{tmpinf}')"
        )
        try:
            incov = ffmpy.FFmpeg(
                inputs={tmpinf: "-y -v " + FFMPEG_LOG}, outputs={TMPFILE: None}
            )
            if not DRY:
                incov.run()
            infile = TMPFILE
        except ffmpy.FFRuntimeError:
            print('-> Couldn\'t fetch cover in "{}".'.format(tmpinf))
            return (None, None, None)

    if (
        not DRY
        and outext != ".png"
        and not subprocess.call(
            r"identify -format '%[channels]' '{}' | grep -qi a".format(
                infile.replace("'", "'\\''")
            ),
            shell=True,
        )
    ):
        print(f"-> Detected alpha channel in cover image. ('{infile}')")
        print(
            '   Do you want to still use "jpg" and'
            ' possibly lose transparent backgrounds'
        )
        print("   (will be filled with black) and save more space"
              " (possibly idk)")
        print('   or do you want to keep transparency by using'
              ' bigger "png" files?')
        if KEEP_TRANSPARENCY == "ask":
            c = input("    Keep transparency (Y/n)?: ")
            if c not in ["n", "N"]:
                outext = ".png"
        elif KEEP_TRANSPARENCY not in ["n", "N"]:
            print("Keeping it.")
            outext = ".png"
        else:
            print("Discarding it.")

    # External cover
    if COVER_SAVE_EXTERN_FILE:
        outfile_ext = to_target_name(
            os.path.join(destination_dir, COVER_BASENAME_SAVE + outext)
        )
        try:
            ff = ffmpy.FFmpeg(
                inputs={infile: "-y -v " + FFMPEG_LOG},
                outputs={outfile_ext: "-vf scale=" + COVER_DIMENSION_EXTERN},
            )
            if not DRY and COVER_SAVE_EXTERN_FILE:
                ff.run()
        except ffmpy.FFRuntimeError:
            outfile_ext = None

    # Internal cover
    if COVER_SAVE_IN_FILES:
        outfile_int = to_target_name("/tmp/tmpintcover" + outext)
        try:
            ff = ffmpy.FFmpeg(
                inputs={infile: "-y -v " + FFMPEG_LOG},
                outputs={outfile_int: "-vf scale=" + COVER_DIMENSION_INTERN},
            )
            if not DRY and COVER_SAVE_EXTERN_FILE:
                ff.run()
        except ffmpy.FFRuntimeError:
            outfile_int = None

    return (infile, outfile_int, outfile_ext)


def read_data_mp3(infile, outfile):
    import mutagen.easyid3

    try:
        f = mutagen.easyid3.Open(infile)

        return {
            "file": outfile,
            "title": f["title"] if "title" in f else None,
            "tracknr": f["tracknumber"] if "tracknumber" in f else None,
            "album": f["album"] if "album" in f else None,
            "artist": f["artist"] if "artist" in f else None,
            "albumartist": f["albumartist"] if "albumartist" in f else None,
            "genre": f["genre"] if "genre" in f else None,
            "year": f["date"] if "date" in f else None,
        }
    except Exception as e:
        print("Error: " + str(infile))
        print(e)
        return None


def read_data_flac(infile, outfile):
    import mutagen.flac

    try:
        f = mutagen.flac.Open(infile)

        return {
            "file": outfile,
            "title": f["title"] if "title" in f else None,
            "tracknr": f["tracknumber"] if "tracknumber" in f else None,
            "album": f["album"] if "album" in f else None,
            "artist": f["artist"] if "artist" in f else None,
            "albumartist": f["albumartist"] if "albumartist" in f else None,
            "genre": f["genre"] if "genre" in f else None,
            "year": f["date"] if "date" in f else None,
        }
    except Exception as e:
        print("Error: " + str(infile))
        print(e)
        return None


def read_data_wma(infile, outfile):
    import mutagen.asf

    try:
        f = mutagen.asf.Open(infile)

        return {
            "file": outfile,
            "title": f["Title"][0].value if "Title" in f else None,
            "tracknr": str(f["WM/TrackNumber"][0].value)
            if "WM/TrackNumber" in f
            else None,
            "album": f["WM/AlbumTitle"][0].value if "WM/AlbumTitle" in f else None,
            "artist": f["Author"][0].value if "Author" in f else None,
            "albumartist": f["WM/AlbumArtist"][0].value
            if "WM/AlbumArtist" in f
            else None,
            "genre": f["WM/Genre"][0].value if "WM/Genre" in f else None,
            "year": f["WM/Year"][0].value if "WM/Year" in f else None,
        }
    except Exception as e:
        print("Error: " + str(infile))
        print(e)
        return None


def read_data_wav(infile, outfile):
    import mutagen.wave

    try:
        f = mutagen.wave.Open(infile)
        # This is buggy? no data?

        return {
            "file": outfile,
            "title": f["title"] if "title" in f else None,
            "tracknr": f["tracknumber"] if "tracknumber" in f else None,
            "album": f["album"] if "album" in f else None,
            "artist": f["artist"] if "artist" in f else None,
            "albumartist": f["albumartist"] if "albumartist" in f else None,
            "genre": f["genre"] if "genre" in f else None,
            "year": f["date"] if "date" in f else None,
        }
    except Exception as e:
        print("Error: " + str(infile))
        print(e)
        return None


def read_data_ogg(infile, outfile):
    import mutagen.flac

    try:
        f = mutagen.flac.Open(infile)

        return {
            "file": outfile,
            "title": f["title"] if "title" in f else None,
            "tracknr": f["tracknumber"] if "tracknumber" in f else None,
            "album": f["album"] if "album" in f else None,
            "artist": f["artist"] if "artist" in f else None,
            "albumartist": f["albumartist"] if "albumartist" in f else None,
            "genre": f["genre"] if "genre" in f else None,
            "year": f["date"] if "date" in f else None,
        }
    except Exception as e:
        print("Error: " + str(infile))
        print(e)
        return None


def write_data_opus(afile, data, cover):
    import mutagen.oggopus

    f = mutagen.oggopus.Open(afile)

    f["title"] = data["title"]
    f["tracknumber"] = data["tracknr"]
    f["album"] = data["album"]
    f["artist"] = data["artist"]
    f["albumartist"] = data["albumartist"]
    f["genre"] = data["genre"]
    f["date"] = data["year"]

    if cover:
        write_cover_opus(afile, cover)


def format_files(aud_files, cover):
    if DRY:
        return
    for infile, outfile in aud_files:
        ext = os.path.splitext(infile)[1].lower()

        if ext == ".mp3":
            data = read_data_mp3(infile, outfile)
        elif ext == ".flac":
            data = read_data_flac(infile, outfile)
        elif ext == ".wma":
            data = read_data_wma(infile, outfile)
        elif ext == ".wav":
            data = read_data_wav(infile, outfile)
        elif ext == ".ogg":
            data = read_data_ogg(infile, outfile)
        else:
            raise NotImplementedError(f"Input not implemented for '{ext}'.")

        ext = os.path.splitext(outfile)[1].lower()
        if ext == ".opus" and data is not None:
            write_data_opus(outfile, data, cover)
        elif data is not None:
            raise NotImplementedError(f"Output not implemented for '{ext}'.")


def walk(source):
    rsource = os.path.realpath(source)
    if os.path.isdir(rsource):
        return os.walk(source, followlinks=True)
    elif os.path.isfile(rsource):
        return [(os.path.dirname(source), [], [os.path.basename(source)])]
    else:
        raise FileNotFoundError(f"file '{source}' not found!")


def source_dir(source):
    if os.path.isfile(os.path.realpath(source)):
        return os.path.dirname(source)
    else:
        return source


def walk_and_convert(sources, destination, skip_hidden=True):
    source_dirs = {source_dir(s) for s in sources}
    if os.path.exists(destination) and len(source_dirs) == 1:
        destination = os.path.join(
            destination, os.path.basename(source_dir(sources[0])))

    total_file_size = 0
    total_file_num = 0
    print("Counting total files to covert...")
    for source in sources:
        for dirname, dirnames, files in walk(source):
            # remove hidden files
            for dirn in dirnames:
                if skip_hidden and dirn.startswith("."):
                    dirnames.remove(dirn)
            files = filter_files(files, AUDIO_EXTENSIONS, skip_hidden)
            total_file_size += sum(
                [
                    os.path.getsize(os.path.join(dirname, filen + ext))
                    for (filen, ext) in files
                ]
            )
            total_file_num += len(files)

    total_progress = Progress(
        name="Total:",
        current_step=0,
        total_steps=total_file_num,
        current_content=0,
        total_content=total_file_size,
        current_time=0,
    )

    print("Converting...")
    for source in sources:
        for dirname, dirnames, files in walk(source):
            # remove hidden files
            for dirn in dirnames:
                if skip_hidden and dirn.startswith("."):
                    dirnames.remove(dirn)

            src_dir = dirname
            reldir = source_dir(source)
            dest_dir = to_target_name(
                os.path.join(
                    destination,
                    os.path.relpath(
                        dirname,
                        start=reldir
                        if len(source_dirs) == 1
                        else os.path.join(reldir, "..")
                    )
                )
            )
            if not DRY and not os.path.exists(dest_dir):
                os.makedirs(dest_dir)

            aud_files = filter_files(files, AUDIO_EXTENSIONS, skip_hidden)
            cov_files = filter_files(files, COVER_EXTENSIONS, skip_hidden)

            print("Entering '{}'...".format(src_dir))
            converted = convert_opus(aud_files,
                                     src_dir,
                                     dest_dir,
                                     total_progress)
            _, internal_cov, _ = convert_cover(
                cov_files, aud_files, src_dir, dest_dir
            )

            if len(converted) > 0:
                print("Formatting '{}'...".format(dest_dir))
            format_files(converted, internal_cov)


if __name__ == "__main__":
    sources = list(map(os.path.abspath, sys.argv[1:-1]))
    destination = os.path.abspath(sys.argv[-1])
    is_fat_fs(destination)
    is_terminal_connected()

    walk_and_convert(sources, destination)
