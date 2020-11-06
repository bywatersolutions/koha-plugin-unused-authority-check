# koha-plugin-unused-authority-check
This plugin checks a batch of authority records to identify unused authorities

To install:
Make sure plugins are enabled on your Koha system

Download the most recent .kpz from the [koha-plugin-unused-authority-check release page](https://github.com/bywatersolutions/koha-plugin-unused-authority-check/releases)

Go to `More->Reports->Report Plugins`
Click 'Upload a plugin' and browse to the kpz file downloaded from the release page

To use:
1. - From the plugins page click 'Run report' for the Unused Authority Report
1. - Enter a range of auhtority ids (record numbers) to check, _or_ enter the creation date of the authority records.
**Note - the plugin has a hardcoded limit of 5000 records**. It is recommended to start with smaller batches
1. - Choose to display results as HTML or download in a CSV
1. - Run the report and view your results


