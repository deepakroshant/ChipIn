# Custom Sounds

Add these .caf audio files to this directory and include them in the Xcode target:

- expense_add.caf  — neutral "faaah" chime (played when adding an expense)
- money_in.caf     — celebratory "haiyo!" (played when someone owes you)
- money_out.caf    — subtle uh-oh tone (played when you owe someone)
- settled.caf      — big satisfying sound (played on settle up complete)

Convert audio files with:
  afconvert -f caff -d ima4 input.m4a output.caf
