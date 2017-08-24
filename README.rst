============================
flask-app-deployment-formula
============================

A saltstack formula created to deploy a Flask-based application into a single
machine or into a machine cluster. 

.. notes::
    It is assumed that the application will be deployed from a git repository.
    The application will be run from inside a python virtualenv, and all 
    dependencies will be sourced form a requirements.txt file that is mandatory
    in the target Git repository.
    The formula will run the application using gunicorn. 


Available states
================

.. contents::
    :local:

``init``
--------

This is all that is required to deploy the application. It will checkout the
code from git, create the virtualenv, and prepare the service for execution.
