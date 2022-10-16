# Installing in Docker

## Installation

This guide will show you how to get akkoma working in a docker container,
if you want isolation, or if you run a distribution not supported by the OTP
releases.

### Prepare the system

* Install docker and docker-compose
  * [Docker](https://docs.docker.com/engine/install/) 
  * [Docker-compose](https://docs.docker.com/compose/install/)
  * This will usually just be a repository installation and a package manager invocation.
* Clone the akkoma repository
  * `git clone https://akkoma.dev/AkkomaGang/akkoma.git -b stable`
  * `cd akkoma`

### Set up basic configuration

```bash
cp docker-resources/env.example .env
echo "DOCKER_USER=$(id -u):$(id -g)" >> .env
```

This probably won't need to be changed, it's only there to set basic environment
variables for the docker-compose file.

### Building the container

The container provided is a thin wrapper around akkoma's dependencies, 
it does not contain the code itself. This is to allow for easy updates
and debugging if required.

```bash
./docker-resources/build.sh
```

This will generate a container called `akkoma` which we can use
in our compose environment.

### Generating your instance

```bash
mkdir pgdata
# if you want to use caddy
mkdir caddy-data
mkdir caddy-config
./docker-resources/manage.sh mix deps.get
./docker-resources/manage.sh mix compile
./docker-resources/manage.sh mix pleroma.instance gen
```

This will ask you a few questions - the defaults are fine for most things,
the database hostname is `db`, and you will want to set the ip to `0.0.0.0`.

Now we'll want to copy over the config it just created

```bash
cp config/generated_config.exs config/prod.secret.exs
```

### Setting up the database 

We need to run a few commands on the database container, this isn't too bad

```bash
docker-compose run --rm --user akkoma -d db 
# Note down the name it gives here, it will be something like akkoma_db_run
docker-compose run --rm akkoma psql -h db -U akkoma -f config/setup_db.psql
docker stop akkoma_db_run # Replace with the name you noted down
```

Now we can actually run our migrations

```bash
./docker-resources/manage.sh mix ecto.migrate
# this will recompile your files at the same time, since we changed the config
```

### Start the server

We're going to run it in the foreground on the first run, just to make sure
everything start up.

```bash
docker-compose up
```

If everything went well, you should be able to access your instance at http://localhost:4000

You can `ctrl-c` out of the docker-compose now to shutdown the server.

### Running in the background

```bash
docker-compose up -d
```

### Create your first user

If your instance is up and running, you can create your first user with administrative rights with the following task:

```shell
./docker-resources/manage.sh mix pleroma.user new MY_USERNAME MY_EMAIL@SOMEWHERE --admin
```

And follow the prompts 

### Reverse proxies

This is a tad more complex in docker than on the host itself. It

You've got two options. 

#### Running caddy in a container

This is by far the easiest option. It'll handle HTTPS and all that for you. 

```bash
cp docker-resources/Caddyfile.example docker-resources/Caddyfile
```

Then edit the TLD in your caddyfile to the domain you're serving on.

Uncomment the `caddy` section in the docker-compose file,
then run `docker-compose up -d` again.

#### Running a reverse proxy on the host

If you want, you can also run the reverse proxy on the host. This is a bit more complex, but it's also more flexible.

Follow the guides for source install for your distribution of choice, or adapt
as needed. Your standard setup can be found in the [Debian Guide](../debian_based_en/#nginx)

### You're done!

All that's left is to set up your frontends. 

The standard from-source commands will apply to you, just make sure you
prefix them with `./docker-resources/manage.sh`!

{! installation/frontends.include !}

### Updating Docker Installs

```bash
git pull
./docker-resources/build.sh
./docker-resources/manage.sh mix deps.get
./docker-resources/manage.sh mix compile
./docker-resources/manage.sh mix ecto.migrate
docker-compose restart akkoma
```

#### Further reading

{! installation/further_reading.include !}

{! support.include !}
