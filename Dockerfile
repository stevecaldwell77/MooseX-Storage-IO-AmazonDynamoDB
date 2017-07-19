FROM perl:latest

# We'll use the 'app' user
ENV APPUSER=app
RUN adduser --system --shell /bin/false --disabled-password --disabled-login $APPUSER

# Setup work dir
ENV APPDIR=/opt/MooseX-Storage-IO-AmazonDynamoDB
RUN install -d -o $APPUSER $APPDIR

# Install dependencies

# This needs to be installed to get Dist::Milla installed (broken dependency
# chain somewhere).
RUN cpanm JSON

# Explicitly install these before using cpanfile, because they take awhile and
# we want to cache them.
RUN cpanm Dist::Milla
RUN cpanm Paws

# Install the rest using cpanfile
ADD cpanfile $APPDIR/
RUN cpanm --installdeps $APPDIR

# Setup to use appuser going forward
USER $APPUSER
WORKDIR $APPDIR
