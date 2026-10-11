import { scrapeEarningsCalendar } from "../sources/calendarScraper";

scrapeEarningsCalendar()
  .then((result) => {
    console.log(result);
  })
  .catch((error) => {
    console.error("Scraping kalendarza nie powiodło się:", error);
    process.exitCode = 1;
  });
