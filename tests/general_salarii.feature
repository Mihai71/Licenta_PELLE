Feature: Flux analiza generala - salarii (SPD / Disparate Impact)
Background:
  * url baseUrl

Scenario: Upload, profilare si metrici binare pe gen -> promovat
  # 1) Upload fisier
  Given path 'upload'
  And multipart file file = { read: 'file:C:/Users/pelle/Downloads/salarii_ro_demo.csv', filename: 'salarii_ro_demo.csv', contentType: 'text/csv' }
  When method post
  Then status 200
  And match response.file_id == '#present'
  * def fid = response.file_id

  # 2) Profilare: tipuri detectate si candidati
  Given path 'profile'
  And form field file_id = fid
  When method post
  Then status 200
  And match response.types.gen == 'Binara'
  And match response.types.promovat == 'Binara'
  And match response.types.salariu_lunar_net_lei == 'Numerica'
  And match response.sensitive_candidates contains 'gen'
  And match response.financial_candidates contains 'salariu_lunar_net_lei'

  # 3) Metrici binare: SPD si DI (asteptam risc de discriminare la promovare)
  Given path 'metrics', 'binary'
  And form field file_id = fid
  And form field sensitive_col = 'gen'
  And form field target_col = 'promovat'
  When method post
  Then status 200
  And match response.spd == '#number'
  And assert response.spd < 0
  And assert response.disparate_impact < 0.8
  And match response.di_interpretation contains 'discriminare'

  # 4) Bias score global
  Given path 'bias-score'
  And form field file_id = fid
  And form field sensitive_col = 'gen'
  And form field target_col = 'promovat'
  When method post
  Then status 200
  And match response.bias_score == '#number'
  And match response.severity == '#present'