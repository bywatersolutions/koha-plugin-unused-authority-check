# koha-plugin-unused-authority-check
This plugin checks a batch of authority records to identify unused authorities

To install:
Make sure plugins are enabled on your Koha
system
Go to More->Reports->Report Plugins
Click 'Upload a plugin' and browse to the kpz file downloaded from the release page

To use:
1 - From the plugins page click 'Run report' for the Unused Authoirty Report
2 - Enter a range of auhtority ids (record numbers) to check
**Note - the plugin has a hardcoded limit of 5000 records and it is recommended to start with smaller batches
3 - Choose to display results as HTML or download in a CSV
4 - Run the report and view your results


