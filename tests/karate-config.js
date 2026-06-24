function fn() {
  var base = 'http://127.0.0.1:8000';
  return {
    // pentru testele API (Karate HTTP)
    baseUrl: base,
    salariiPath: 'C:/Users/pelle/OneDrive/Downloads/salarii_ro_demo.csv',
    essCsv: 'C:/Users/pelle/OneDrive/Downloads/ESS_DATA_CLEAN.csv',

    //pentru UI automation (Karate driver pe Shiny)
    appUrl: 'http://127.0.0.1:3838',
    salariiPath: 'C:/Users/pelle/Downloads/salarii_ro_demo.csv'
  };
}