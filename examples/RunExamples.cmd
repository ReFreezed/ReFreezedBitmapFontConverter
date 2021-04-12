@ECHO OFF
CD %~dp0
SET exe=..\RbmfConverter.exe
IF [%1] NEQ []  SET "exe=%*"

REM  Output everything to the output/ folder.
IF NOT EXIST output  MD output



REM  Convert a normal bitmap font to BMFont.
%exe% smallPixel.rbmf --outdir output || EXIT /B 1

REM  Rasterize a TrueType font to BMFont while greatly limiting the image size.
%exe% vector.rbmf --outdir output --maxsize 100 || EXIT /B 1

REM  Create a BMFont out of a bitmap font using a filter, and another
REM  BMFont as fallback containing glyphs missing from the first font.
%exe% chain1.rbmf --outdir output --filter chainCharacters.txt --missing output/chainMissing.txt || EXIT /B 1
%exe% chain2.rbmf --outdir output --textfile output/chainMissing.txt || EXIT /B 1
