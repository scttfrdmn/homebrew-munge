# Homebrew MUNGE

A Homebrew tap for installing MUNGE on macOS.

MUNGE (MUNGE Uid 'N' Gid Emporium) is an authentication service for creating and validating user credentials. It is designed to be highly scalable for use in an HPC cluster environment.

## Installation

First add the tap, then install munge:

    brew tap scttfrdmn/munge
    brew install munge

## Usage

Generate and validate a credential:

    munge -n | unmunge

Start the MUNGE daemon:

    brew services start munge

## For Slurm Clusters

Copy munge key from your cluster head node:

    sudo cp /path/to/munge.key $(brew --prefix)/etc/munge/

Set proper permissions:

    sudo chown $(whoami):staff $(brew --prefix)/etc/munge/munge.key
    sudo chmod 400 $(brew --prefix)/etc/munge/munge.key

Start munge service:

    brew services start munge

## macOS Build Notes

This formula includes patches to make MUNGE build cleanly on macOS by handling the libmissing compatibility issues.
