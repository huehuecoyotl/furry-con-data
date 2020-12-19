# furry-con-data
A tool that creates the CSVs behind the furry convention data visualizations served at [https://coyo.tl/viz](https://coyo.tl/viz)

## Would you like to help?
Updating the visualization is as easy as a pull request! Simply create a new CSV and put it in the raw_data folder, or update an existing CSV with new data, and your updates can be live quickly and easily. The format of the CSV files is simple. The first line contains only the name of the convention. From there, the data is organized by line, where the first column is the date of the final Sunday of the event, and the second column is that year's attendance. The data should be sorted by date, with the first year of events at the top. From there, the tool builds everything else on its own and feeds it into the site as needed!

To summarize:

Date of final Sunday of event|Attendance
 --- | --- 
