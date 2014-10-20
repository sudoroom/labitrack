This is the inventory tracking system for the Labitat hackerspace in Copenhagen and now also the sudo room hackerspace in Oakland, California.

It is a web app written in lua, backed by a postgresql database, that prints stickers containing QR-codes and human readable text using an affordable Brother QL-570 thermal label printer.

Each item can have its own wiki page (on a wiki that is separate from this web app).

# Installing dependencies

```
sudo apt-get install lua5.1 build-essential nodejs npm inotify-tools git pkg-config libpq5 libpq-dev postgresql-9.3 postgresql-contrib

cd /usr/bin

ln -s nodejs node

sudo npm install -g handlebars uglify-js coffee-script lessc

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

# Compiling

```
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

cd labitrack/
mkdir -p queue/tmp
mkdir -p queue/new

# Testing

```
./start.sh
```

If you don't get any errors, everything is fine and dandy. Hit ctrl-c to exit.

# Running

You probably want to use e.g. apache or nginx as a reverse proxy and you will want to make labitrack automatically start and stop when the server boots and shuts down.

TODO (use the npm library "forever" to automatically restart labitrack if it crashes)
