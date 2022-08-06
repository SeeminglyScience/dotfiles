@ECHO OFF
echo %~1|%USERPROFILE%\scoop\apps\git\current\usr\bin\base64.exe -d 2>nul|gzip -c -d
