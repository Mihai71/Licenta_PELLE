@llm
Feature: LLM, interpretare clustering + intrebare custom (via Ollama)

# Necesita Ollama pornit local (modelul din llm.R, ex: qwen2.5:14b).
# Generarea poate dura zeci de secunde - de aceea readTimeout e marit.

Background:
  * url baseUrl
  * configure readTimeout = 300000

Scenario: Clustering ESS -> interpretare LLM -> intrebare despre bias intersectional
  # Upload ESS original (cu gndr=9)
  Given path 'upload'
  And multipart file file = { read: 'file:C:/Users/pelle/Downloads/ESS10e03_3-ESS10SCe03_2-ESS11custom/ESS_training_clean.csv', filename: 'ESS_training_clean.csv', contentType: 'text/csv' }
  When method post
  Then status 200
  * def fid = response.file_id

  # 1) Clustering cu interpretare LLM (testul trece cand vine textul)
  Given path 'llm', 'interpret'
  And form field file_id = fid
  And form field col_sex = 'gndr'
  And form field col_age = 'agea'
  And form field col_edu = 'eisced'
  And form field col_env = 'domicil'
  And form field col_income = 'hinctnta'
  And form field n_clusters = 3
  When method post
  Then status 200
  And match response.text == '#string'
  And assert response.text.length > 50

  # 2) Intrebare custom: ce este biasul intersectional?
  Given path 'llm', 'chat'
  And form field message = 'Ce este biasul intersectional? Explica pe scurt.'
  When method post
  Then status 200
  And match response.text == '#string'
  And assert response.text.length > 30