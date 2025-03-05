set StartupDelay 0

echo Detecting boot drive and loading custom bootloader...

for %i in fs0 fs1 fs2 fs3 fs4 fs5
  if exist %i:\EFI\BOOT\VX64.EFI then
    echo Found bootloader on %i:
    %i:
    cd \EFI\BOOT
    echo Launching bootloader with parameters: root=live:LABEL=ESP boot=live live-media-path=/live components toram
    VX64.EFI root=live:LABEL=ESP boot=live live-media-path=/live components toram
    goto END
  endif
endfor

echo Error: Could not find a valid bootloader.
pause

:END
