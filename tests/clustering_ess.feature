@api
Feature: Flux clustering K-Means (ESS) - elbow + clustering + atribut extra cntry

Background:
  * url baseUrl

Scenario: Upload ESS, elbow, clustering k=3, apoi reclustering cu cntry
  # Upload ESS original
  Given path 'upload'
  And multipart file file = { read: 'file:C:/Users/pelle/Downloads/ESS10e03_3-ESS10SCe03_2-ESS11custom/ESS_training_clean.csv', filename: 'ESS_training_clean.csv', contentType: 'text/csv' }
  When method post
  Then status 200
  * def fid = response.file_id

  # 1) Metoda Elbow
  Given path 'elbow'
  And form field file_id = fid
  And form field col_sex = 'gndr'
  And form field col_age = 'agea'
  And form field col_edu = 'eisced'
  And form field col_env = 'domicil'
  And form field col_income = 'hinctnta'
  When method post
  Then status 200
  And match response.suggested_k == '#number'
  And match response.elbow_data == '#[_ > 0]'

  # 2) Clustering k=3
  Given path 'clustering'
  And form field file_id = fid
  And form field col_sex = 'gndr'
  And form field col_age = 'agea'
  And form field col_edu = 'eisced'
  And form field col_env = 'domicil'
  And form field col_income = 'hinctnta'
  And form field n_clusters = 3
  When method post
  Then status 200
  And match response.n_clusters == 3
  And match response.profiles == '#[3]'
  And match response.bias_per_cluster == '#[3]'

  # 3) Reclustering cu atribut suplimentar: cntry (tara)
  Given path 'clustering'
  And form field file_id = fid
  And form field col_sex = 'gndr'
  And form field col_age = 'agea'
  And form field col_edu = 'eisced'
  And form field col_env = 'domicil'
  And form field col_income = 'hinctnta'
  And form field n_clusters = 3
  And form field col_extra_json = '["cntry"]'
  When method post
  Then status 200
  And match response.n_clusters == 3
  And match response.profiles == '#[3]'