import random
import subprocess
import string
import sys
from os import path
import os

# We'll need to be able to write to /dev/null, so open a writable stream to /dev/null.
nullfeed = open(os.devnull, 'w')


def main():
    # Halt execution if less than two arguments.
    if len(sys.argv) < 2:
        print("Usage: batchacct.py /path/to/userfile.txt")
        exit()

    # Halt execution if the second argument isn't a valid file.
    elif not path.exists(sys.argv[1]):
        print("Error: File {} doesn't exist.".format(sys.argv[1]))
        exit()

    # Let's load the file, read-only. This will close the file when we're done with it.
    with open(sys.argv[1], "r") as user_file:
        # Process each name. This will run for each line in the file.
        for line_num, fullname in enumerate(user_file):

            # Split the line into a list of words.
            name_list = fullname.split()

            # name_list[0][0] returns the first letter of the first word.
            # name_list[-1] returns the full last word.
            # Concatenate these with a period in the middle. Ensure everything is lowercase.
            orig_username = name_list[0][0].lower() + '.' + name_list[-1].lower()
            username = orig_username

            # Initialize a variable, does_exist, with 0. This will be changed by the loop we're going to run.
            does_exist = 0

            # This following loop will return as long as we don't have a unique username, but will run at least once.
            while does_exist == 0:

                # run id with the username as an argument. If it exists, it will return without error.
                # use /dev/null as stdout and stderr for clean output. We don't need it.
                existing = subprocess.run("/usr/bin/id -u {}".format(username),
                                          shell=True, stdout=nullfeed, stderr=nullfeed)

                # Replace the value of does_exist with the return code of id.
                does_exist = existing.returncode

                # If the username exists, id returns without error, so create new username with random nums at end.
                if does_exist == 0:
                    username = orig_username + str(random.randint(0, 99999))

            # Password will be 16 random characters, with each character being a letter, a number, or punctuation.
            password = ''.join(random.choices(string.ascii_letters + string.digits + string.punctuation, k=16))

            # Print the username and password. We'll do more with this later.
            print(username + ' ' + password)


# Ensure this  is being run as a script, not imported as a module.
if __name__ == "__main__":
    main()
else:
    print("ERROR: This is a script, not a module.")
    print("Usage: batchacct.py /path/to/userfile.txt")
