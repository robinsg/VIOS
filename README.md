# VIOS
VIOS scripts

Installation

Log in to you VIOS LPAR and type

$ oem_setup_env

this takes you to AIX mode




Step 1 - Add the .kshrc file

Type the following commands whilst in oem_setup_env

# vi .kshrc

Then press i to insert and paste the .kshrc file in to the screen

to quit vi
Esc :wq
This will save and quit back to the command line



Step 2 - Update the .profile file

Type the following commands whilst in oem_setup_env

chmod +w /usr/ios/cli/.profile

vi /usr/ios/cli/.profile

type G to to very last line in file
type $ to go to the end of the line
type a to add line, then press enter

Add to last line >>>>>>> . $HOME/.profile.padmin (copy from  . to n)

to quit vi
Esc :wq

chmod -w /usr/ios/cli/.profile


******* NB After a VIOS software update the .profile file will be overwritten
******* Repeat step 2 to add the .$HOME/.profile.padmin line is added back in to to /usr/ios/cli/.profile file



Step 3 - Add the .profile.padmin file 

vi .profile.padmin

Then press i to insert, then paste the .profile.padmin file into the screen
