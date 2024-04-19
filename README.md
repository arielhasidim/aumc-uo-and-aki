# AmsterdamUMCdb hourly-adjusted urine output and AKI analysis

SQL queries and R workflow to create datasets for hourly-adjusted urine output (UO) and AKI events as well as the original research results from the [AmsterdamUMCdb](https://amsterdammedicaldatascience.nl/amsterdamumcdb/). 
This repository accompanies the article: *"Method for computerized standardization of arbitrary urinary output charting for the diagnosis of AKI: A derivation-validation proof of concept study using two multicenter databases"*.

## Table of contents

* [Introduction](#introduction)
* [Main Objectives and Structure](#main-objectives-and-structure)
* [Requirements and Compatability](#requirements-and-compatability)
* [Example](#example)
* [Citation](#citation)

## Introduction

Accurate diagnosis and analysis of oliguric-AKI relies on timely UO charting. However, charting is often limited by irregular collection intervals, inadequate charting practices, and overlooked urine accumulation compartments. We aimed to establish a method for standardizing hourly UO using real-life charting data and to examine whether this method can identify oliguric-AKI. We also aimed to validate the method externally. 

The model described, based on simple charting, can be used across the board for oliguric-AKI research. It can be utilized to detect the onset and resolution of AKI events, label AKI stages, and summate fluid balance in an hourly resolution. It may serve to analyze publicly available DBs and data sourced from standard EHRs as well as custom-made data in Excel tables. 

This repository is addressing the validation cohort. 

For the derivation cohort see: https://github.com/arielhasidim/mimic-uo-and-aki

## Main Objectives and Structure

This repository has two main objectives:

1. **Enable the creation of hourly-adjusted UO and AKI events tables** - For further instructions visit: `create_data/...`.

2. **Enable the reproduction of the associtated article** - For further instructions visit: `reproduce_article/...`.

## Requirements and Compatability

 - The AmsterdamUMC database is **required** in order to run this code and is not provided with this repository. 
 - To access the AmsterdamUMCdb, you will need to request access according to the guidance on the [official website](https://amsterdammedicaldatascience.nl/amsterdamumcdb/).
 - See also the [official repository](https://github.com/AmsterdamUMC/AmsterdamUMCdb).
 - The queries and workflow included here depend on Google's Bigquery cloud service. Researchers who want to use the suggested workflow need to download the AmsterdamUMC dataset tables in full and upload them manually to a Bigquery dataset named "original" within their personal project folder. See the workflow in the screenshot below for reference.
 - You will need a Google Cloud Platform (GCS) billing account to run the queries.
 - The SQL queries are written in GoogleSQL dialect (formally known as "Standard-SQL" dialect) and is probably compatible with other common dialects.
 - The code was tested on AmsterdamUMCdb v1.0.2.

<a href="https://github.com/arielhasidim/aumc-uo-and-aki/assets/23483971/5fbf47e4-f28a-485b-a402-6daca33f9d00"><img src="https://github.com/arielhasidim/aumc-uo-and-aki/assets/23483971/5fbf47e4-f28a-485b-a402-6daca33f9d00" width="300px" ></a>

## Example

After creating all the tables and reproducing the associated study, you should end up with a result page in HTML format: https://arielhasidim.github.io/aumc-uo-and-aki.

## Citation

........
