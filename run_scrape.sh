#!/bin/bash

# Set the URL of the Framer page
URL="https://rbconcretelevel.framer.website/"

# Directory where the files will be saved
WORKDIR="/home/jenkins/scraped-site"

# Create the working directory if it doesn't exist
mkdir -p $WORKDIR

# Use wget to scrape the page
wget --mirror --page-requisites --adjust-extension --convert-links --no-parent -P $WORKDIR $URL

# If there are any changes, copy the files and commit them
cd $WORKDIR

# Copy files to the repo directory (assuming your repo is set up)
cp -a $WORKDIR/* /var/lib/jenkins/workspace/Framer_Scraper/

# Go back to repo directory and check git status
cd /var/lib/jenkins/workspace/Framer_Scraper/

# Check git status and commit any changes
git add -A
git commit -m "Scraped Framer Site Content" || echo "No changes to commit"
