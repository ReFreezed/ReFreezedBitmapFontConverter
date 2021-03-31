ReFreezed Bitmap Font converter
Developed by Marcus 'ReFreezed' Thunström

Website: https://github.com/ReFreezed/ReFreezedBitmapFontConverter

1. Disclaimer
2. Intro
3. Command line interface
4. Font image
5. Font descriptor
6. Icons



1. Disclaimer
==============================================================================

The software is provided "as is", without warranty of any kind, express or
implied, including but not limited to the warranties of merchantability,
fitness for a particular purpose and noninfringement. In no event shall the
authors or copyright holders be liable for any claim, damages or other
liability, whether in an action of contract, tort or otherwise, arising from,
out of or in connection with the software or the use or other dealings in the
software.



2. Intro
==============================================================================

This program was made as a tool for the LÖVE game framework, but if your game
understands BMFont files then this program may very well be useful for you.

LÖVE supports two bitmap font formats: AngelCode's BMFont, and its own format.

LÖVE's own font format is very simple but also very limited. The BMFont format
has all the necessary features for rendering fonts nicely, but its files are
very user-unfriendly to edit by hand. This program tries to simplify the
creation of BMFont files using a font file format that's similar to LÖVE's.

The ReFreezed Bitmap Font consists of two files: an image with all the glyphs
separated by a border (similar to LÖVE's format, but with multiple rows) and a
descriptor file (.rbmf) that specifies what glyphs are in the image (but not
any coordinates, unlike BMFont).



3. Command line interface
==============================================================================

$ RbmfConverter.exe inputPath1 [inputPath2 ...] [options]

Input paths can be font descriptor files or directories with .rbmf files.
The filenames of outputted files is specified in each font descriptor.

Options:

    --outdir <outputDirectory>
    Where to output files. (Default: Same directory as the input.)

    --icons <outputFilePath>
    Where to put the icons file if any icons are specified in any of the input
    files. (Default: <outputDirectory>/.fonticons)

    --mergeicons
    Merge new icons with existing icons if the icons file already exists.
    (Default: Icons file is replaced)

    --maxsize <imageSize>
    Maximum width and height of outputted images. (Default: 2048)

    --textfile <filePath1> [--textfile <filePath2> ...]
    Note: Relative paths will be relative to the current working directory,
    unlike the 'textFile' input parameter in the descriptor.



4. Font image
==============================================================================

The bitmap font image consists of multiple rows of glyphs ordered from left to
right with each row and glyph separated by a one pixel wide border. The top
left pixel in the image determines what color the border is. The areas between
the borders are interpreted as the actual font glyphs. Any extra pixels to the
right of the rightmost glyph on each row, or anything below the last row, is
ignored. All rows must be the same height. (See the examples folder for
example images.)



5. Font descriptor
==============================================================================

The structure of a font descriptor is similar to an .ini file. It consists of
[sections] followed by several key=value pairs. Lines starting with "#" are
ignored by the program. All parameters are optional unless specified
otherwise.

File structure:

    # The first line is the file version. This must currently always be '1'.
    # Required parameter!
    version=1


    # The [in] section contains some general information about the input image.
    [in]

    # Specify whether the image is colored or monochrome. Monochrome images
    # may become more optimized. Possible values are 'true' or 'false'.
    # (Default: true)
    colored=bool


    # The [edit] section describes how the input image should be preprocessed
    # before anything else happens.
    [edit]

    # If the image for some reason contains unwanted half-transparent pixels,
    # this threshold determines what pixels should be fully opaque or
    # completely transparent. The values should be a number between 0 and 1.
    # (Default: 0, which means pixels are not edited)
    alphaThreshold=threshold


    # [out] sections (of which there can be multiple) specifies how the font
    # should be processed, outputted and finally rendered. One .rbmf
    # descriptor file can output multiple BMFont files. There should be at
    # least one [out] section, otherwise the program doesn't really do
    # anything!
    [out]

    # Filename of the outputted image, e.g. "<name>.png" (<name> will be
    # replaced by the descriptor's filename). Required parameter!
    fileImage=filename

    # Filename of the outputted BMFont descriptor, e.g. "<name>.fnt"
    # (<name> will be replaced by the .rbmf descriptor's filename). Required
    # parameter!
    fileDescriptor=filename

    # Width of the outline, if an outline should be added by the program.
    # (Default: 0, no outline is added)
    outlineWidth=1

    # Color of the outline, if one is added. The values should be numbers
    # between 0 and 1. (Default: 0 0 0 1)
    outlineColor=red green blue alpha

    # Method used for creating the outline, if one is added. Possible values
    # are 'auto' or 'basic'. 'auto' tend to look smoother and nicer for
    # 1-pixel outlines. Thicker outlines currently always use 'basic'.
    # (Default: auto)
    outlineMethod=outlineMethod

    # Extra space around each glyph. Note that when the text is rendered this
    # padding will be part of each glyph (i.e. more pixels will be rendered
    # around each character, which may be useful for custom shaders). Also
    # note that padding does not affect the distance between characters when
    # rendered - that's what renderSpacing and kerning is for. Setting this to
    # a positive number may remove black fringe around glyphs when text is
    # rendered rotated/scaled or at non-integer coordinates if linear
    # interpolation is used. The value have multiple formats.
    glyphPadding=padding
    glyphPadding=vertival horizontal
    glyphPadding=up horizontal down
    glyphPadding=up right down left

    # Extra space between glyphs. The value have multiple formats.
    glyphSpacing=spacing
    glyphSpacing=vertival horizontal

    # Extra space between the glyphs and the image border. The value have
    # multiple formats.
    imagePadding=padding
    imagePadding=vertival horizontal

    # Set the distance between glyphs when rendered (in addition to any
    # kerning). (Default: 1)
    renderSpacing=spacing

    # Specify whether the padding should affect the distance between glyphs
    # when rendered. Possible values are 'true' or 'false'. (Default: false)
    paddingAffectsRenderSpacing=bool

    # Specify whether the outline, if one is added, should affect the distance
    # between glyphs when rendered. Possible values are 'true' or 'false'.
    # (Default: false)
    outlineAffectsRenderSpacing=bool

    # You can embed multiple custom values in the outputted BMFont file using
    # this format.
    custom.someName=someValue
    # Examples:
    custom.lineHeight=1.2
    custom.isBig=true
    # These will show up at the end of the 'info' line in the BMFont file like this:
    # info face="" (...) CUSTOM_lineHeight=1.2 CUSTOM_isBig="true"


    # Sections with numbers as names specify what glyphs are on each row in
    # the input image, from left to right. This would be row 1.
    [1]

    # The glyphs on the row. (Space counts as a character!)
    glyphs=ABCDEFGHIJKLMNOPQRSTUVWXYZÅÄÖÜ
    glyphs=abcdefghijklmnopqrstuvwxyzåäöü
    glyphs= -.,:!?

    # Multiple lines with glyphs=whatever will be joined together by the
    # program. The line below means the same thing as the three lines above.
    glyphs=ABCDEFGHIJKLMNOPQRSTUVWXYZÅÄÖÜabcdefghijklmnopqrstuvwxyzåäöü -.,:!?

    # If the font has icons in it (or any custom characters) you can use the
    # 'icons' parameter. These get assigned unique Unicode codepoints by the
    # program. Like the 'glyphs' parameter, multiple lines with icons=whatever
    # will be joined together by the program. The value is a list of space-
    # separated names. (See the Icons chapter for more info.)
    icons=dpadUp dpadRight dpadDown dpadLeft
    icons=ogre wizard sword

    # 'glyphs' and 'icons' parameters can be mixed together.
    [2]
    glyphs=€$£
    icons=arrowLeft arrowRight
    glyphs=^~
    icons=home exit


    # Finally, the [kerning] section specifies glyphs which should be rendered
    # closer together (or further apart).
    [kerning]

    # There are two ways of specifying kerning:
    #   1) any of 'abc' followed by any of 'xyz'
    #   2) any of 'abc' followed by any of 'xyz' AND any of 'xyz' followed by any of 'abc'


    # Way 1, forward (left to right):
    forward=groupBefore groupAfter offset
    forward=groupBefore group groupAfter offset

    # Examples:

    forward=f acdefgmnopqrsuvwxyz.,_ -1
    # This means any of these: f
    # followed by any of these: acdefgmnopqrsuvwxyz.,_
    # should be 1 pixel closer together.

    forward=Lbhkt T d -1
    # This means any of these: Lbhkt
    # followed by any of these: T
    # AND any of these: T
    # followed by any of these: d
    # should be 1 pixel closer together.


    # Way 2, bothways:
    bothways=groupA groupB offset

    # Example:

    bothways=Vv .,_ -2
    # This means any of these: Vv
    # followed by any of these: .,_
    # AND the reverse, any of these: .,_
    # followed by any of these: Vv
    # should be 2 pixels closer together.


    # The following two lines produce the same result.
    bothways=Vv .,_ -2
    forward=Vv .,_ Vv -2



The program also has some support for rasterizing TrueType/OpenType fonts
(called vector fonts here). There are some additional parameters in this case,
and some things work a bit differently.

File structure, in addition to the above:

    [in]

    # Filename of the font. Note that a relative path is relative to the .rbmf file.
    fontFile=OpenSans-Regular.ttf

    # The size of the font.
    fontSize=24

    # TrueType hinting mode (for anti-aliasing). Possible values are 'normal',
    # 'light', 'none' or 'mono'. 'mono' disables anti-aliasing while the
    # others control the level of hinting. (Default: normal)
    fontHinting=hintingMode

    # Filename of a text file containing all characters you want to rasterize.
    # You can use this instead of, or in conjunction with, numbered sections.
    # (Every character will only be rasterized once.) There can be multiple
    # 'textFile' parameters. Note that relative paths are relative to the
    # .rbmf file.
    textFile=filename1
    textFile=filename2

    # The row number doesn't matter for vector fonts as there's no concept of
    # a "row", so it's fine to put all characters under the same row number
    # (e.g. 1).
    [1]
    chars=ABCDEFGHIJKLMNOPQRSTUVWXYZÅÄÖÜ
    chars=abcdefghijklmnopqrstuvwxyzåäöü

    # Note that icons don't work for vector fonts.

    # Also, the program currently doesn't use any kerning information from
    # vector fonts - that information will have to added manually just like
    # for bitmap fonts.



6. Icons
==============================================================================

The assigned codepoints for the icons are exported to the specified icons file
with this format:

    codepoint1 name1
    codepoint2 name2
    ...

You can use this information in your game to replace icon placeholders in
strings with the actual characters representing the icons, for example like
this:

    local icons = {}

    for line in love.filesystem.lines(".fonticons") do
        local cp, name = line:match"(%d+) (%S+)"
        icons[name]    = require"utf8".char(tonumber(cp))
    end

    local text = ("{ogre} picked up {sword}"):gsub("{(%w+)}", icons)
    love.graphics.print(text)



==============================================================================
