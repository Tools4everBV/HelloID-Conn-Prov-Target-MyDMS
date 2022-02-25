# HelloID-Conn-Prov-Target-MyDMS

| :warning: Warning |
|:---------------------------|
| Note that this HelloID connector has not been tested in a production environment!      |

| :information_source: Information |
|:---------------------------|
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.       |

## Table of contents

- [Introduction](#Introduction)
- [Getting started](#Getting-started)
  + [Connection settings](#Connection-settings)
  + [Prerequisites](#Prerequisites)
  + [Remarks](#Remarks)
- [Setup the connector](@Setup-The-Connector)
- [Getting help](#Getting-help)
- [HelloID Docs](#HelloID-docs)

## Introduction

_HelloID-Conn-Prov-Target-MyDMS_ is a _target_ connector. MyDMS provides a set of REST API's that allow you to programmatically interact with it's data. The connector contains Account and Authorization management.


## Getting started

### Connection settings

The following settings are required to connect to the API.

| Setting      | Description                        | Mandatory   |
| ------------ | -----------                        | ----------- |
| UserName     | The UserName to connect to the API | Yes         |
| Password     | The Password to connect to the API | Yes         |
| BaseUrl      | The URL to the API                 | Yes         |

### Prerequisites
- Only the connection settings are required

### Remarks
 - There are no enable and disable scripts because the _startEmployment is required when creating a user. And the account will be disabled in the delete action, with putting an Enddate (Get-date) - one day) on the user.
 - _startEmployment must always be a valid date (dd-mm-yyyy). This will activate the user account on or after that date.
 - _endEmployment can be passed either empty (=account is active) or as a valid end date (dd-mm-yyyy). This will deactivate the account after that date.

## Setup the connector

## Getting help

> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/hc/en-us/articles/360012558020-Configure-a-custom-PowerShell-target-system) pages_

> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/
