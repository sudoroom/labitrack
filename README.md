This is the inventory tracking system for the Labitat hackerspace in Copenhagen and now also the sudo room hackerspace in Oakland, California.

It is a web app written in lua, backed by a postgresql database, that prints stickers containing QR-codes and human readable text using an affordable Brother QL-570 thermal label printer.

Each item can have its own wiki page (on a wiki that is separate from this web app).

# Downloading 

```
cd ~/
git clone https://github.com/sudoroom/labitrack

sudo mv labitrack /opt/labitrack
```

# Installing dependencies

```
sudo apt-get install lua5.1 build-essential nodejs npm inotify-tools git pkg-config libpq5 libpq-dev postgresql-9.3 postgresql-contrib libpng12-0 libpng12-dev

cd /usr/bin

ln -s nodejs node

sudo npm install -g handlebars@1.0.4-beta uglify-js coffee-script lessc

cd ~/labitrack
git clone https://github.com/sudomesh/ql570
cd ql570
make
cd ../

git clone https://github.com/esmil/lem.git
cd lem
./configure
make
sudo make install
cd ../

git clone https://github.com/esmil/lem-postgres
cd lem-postgres
make
sudo make install
cd ../

git clone https://github.com/sudomesh/ql570.git

```

# Setting up the PostgreSQL server and database

```
sudo su postgres

psql
create user labitrack with password 'my_password';
create database labitrack;
grant all privileges on database labitrack to labitrack;
\q

createlang -d labitrack plpgsql
psql labitrack < sql/labitrack.schema.sql

logout
```

# Customizing for your hackerspace

Before compiling, you will want to find and replace where sudoroom is mentioned, especially the places where o.sudoroom.org is used, since that will be put into every QR-code generated.

# Compiling

```
make
```

You can always recompile if you change something:

```
make clean
make
```

# Configuring

First run:

```
chmod 750 labitrack/web/labitrackd.lua
```

Then in the file labitrack/web/labitrackd.lua change the line that looks like:

```
local pg_connect_str = 'host=localhost user=labitrack dbname=labitrack password=my_password'
```

setting the password to whatever you chose earlier.

# Create required paths

```
cd labitrack/
mkdir -p queue/tmp
mkdir -p queue/new
```

# Setting up the label printer

Plug in the label printer (power and usb). It should appear as:

```
/dev/usb/lp0
```

If it comes up as something else, then change the following line in printloop.sh:

```
printer="/dev/usb/lp0"
```

If you get an error where the printer blinks a red light when you attempt to print, try altering the command line option for the ql570 program in trigger.sh file. Changing the 'w' to an 'n' or vice-versa might fix the issue. Look at ql570/README.md for more info.

# Testing

```
./start.sh
```

If you don't get any errors, everything is fine and dandy. Hit ctrl-c to exit.

# Running as a service

This sections shows you how to run labitrack as a service that gets automatically restarted using psy.

First install psy:

```
sudo npm install -g psy
```

Then copy the upstart scripts to /etc/init.d:

```
sudo cp init/labitrack.initd /etc/init/labitrack
sudo cp init/labitrack-printloop.initd /etc/init/labitrack-printloop
```

If you are not running labitrack from /opt/labitrack then alter the paths in those scripts before proceeding.

Create the labitrack user:

```
adduser labitrack
```

Make it a member of the lp group so it can access the printer:

```
usermod -a -G lp labitrack
```

Set permissions:

```
chown -R labitrack.labitrack your/path/to/labitrack
```

Now start labitrack:

```
sudo /etc/init.d/labitrack start
sudo /etc/init.d/labitrack-printloop start
```

You can verify that labitrack is running by doing:

```
sudo /etc/init.d/labitrack status
```

Check again after a couple of minutes to ensure that labitrack isn't constantly restarting (watch to see if the PIDs change).


