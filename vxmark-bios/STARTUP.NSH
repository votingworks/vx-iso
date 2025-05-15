set StartupDelay 0

echo Searching for vxmark bios update...

for %i in fs0 fs1 fs2 fs3 fs4 fs5
  if exist %i:\EFI\BOOT\flash.nsh then
    echo Found bios update on %i:
    %i:
    cd \EFI\BOOT
    flash.nsh
    goto END
  endif
endfor

echo Error: Could not find a vxmark bios update.
pause

:END
