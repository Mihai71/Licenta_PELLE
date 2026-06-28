# Aplicația pentru detectarea și vizualizarea aspectelor părtinitoare în seturi de date

Aplicație interactivă pentru detectarea aspectelor părtinitoare (bias) în seturi de date socio-economice publice. Combină R Shiny (interfață) cu Python (procesare
statistică și machine learning, prin reticulate) și un LLM local (via Ollama) pentru interpretarea automată a rezultatelor, fără ca datele să părăsească calculatorul, conform GDPR.

Funcționalități principale:
- profilarea și preprocesarea datelor, ce include filtre, editare, duplicate, valori lipsă;
- metrici de disparitate, anume Cohen's d, eta pătrat, t-test Welch, ANOVA, SPD, Disparate Impact, Bias Score;
- analiză socio-demografică standardizată (grupe de vârstă, niveluri ISCED, regiuni NUTS) cu comparație față de referințe salariale în lei (RON);
- clustering K-Means nesupervizat cu PCA și analiză de bias intra-cluster;
- interpretare în limbaj natural cu un model LLM rulat local.


## 1. Arhitectură

Interfață, în R Shiny (`app.R`) care formează un dashboard interactiv, rulat pe port 3838 
API REST în R Plumber (`api.R`), aceeași logică expusă a aplicației sub formă de endpoint-uri HTTP, rulat pe port 8000 
Motor de calcul în Python (`logic.py`, `clustering.py`), conțin metrici, statistici, K-Means, PCA 
Interpretare AI prin Ollama (local) plus fișierul în R `llm.R` ce generează interpretarea în română 
Testare prin Karate (opțional), teste API și automatizare UI 

Aplicația și API-ul sunt independente (porturi diferite), dar folosesc același motor Python.



## 2. Prerechizite (de instalat o singură dată)

1. R ≥ 4.2 — https://cran.r-project.org/ (recomandat și RStudio Desktop)
2. Python ≥ 3.9 — https://www.python.org/downloads/ (la instalare se bifează „Add Python to PATH")
3. Ollama — https://ollama.com/download (pentru interpretarea LLM)
4. (opțional, doar pentru rularea testelor) Java ≥ 11 și `karate.jar`


## 3. Instalare

### Pasul 1: Proiectul, Dependințele R și Python
Creează un folder nou, gol, unde să imporți de pe git proiectul
Deschide R/RStudio și setează directorul de lucru pe folderul proiectului, cel creat anterior, (acolo unde se află `app.R` și `setup.R`). 
În RStudio, asigură-te că ai setat în consolă ca Working directory, folderul cu proiectul (în caz contrar, rulează în respectiva consolă setwd("CALEA/CATRE/proiect")).
Apoi rulează o singură dată: source("setup.R")

Acest script:
- instalează toate pachetele R necesare;
- alege automat un Python valid din sistem și creează din el un mediu Python izolat numit `biasapp` care va permite aplicației să ruleze. 

La final ar trebui să vezi mesajele `Python de baza ales: ...` și `Mediul Python 'biasapp' a fost creat`.

> **Important:** după ce ai rulat `setup.R`, repornește sesiunea R (sau repornește R studio complet) înainte de a porni aplicația. 

### Pasul 2: Modelul LLM în Ollama
Într-un terminal, rulează comanda: ollama pull qwen2.5:14b

Atenție! Modelul se poate schimba manual din `llm.R`, variabila `LLM_DEFAULT_MODEL`. Pentru calculatoare
mai modeste se poate folosi un model mai mic, ex. `gemma2:9b` sau `qwen2.5:7b`.


## 4. Rulare

### Aplicația (interfața)
În consola R, din folderul proiectului: shiny::runApp(port = 3838), apoi deschide `http://127.0.0.1:3838` în browser sau pur și simplu din butonul de run, cu app.R deschis.

Pentru interpretarea AI, Ollama trebuie să ruleze (`ollama serve`).

### API-ul REST (opțional)

source("run_api.R")

Documentația interactivă (Swagger): `http://127.0.0.1:8000/__docs__/`

### Testele (opțional)
Cu API-ul pornit, dintr-un terminal în folderul `tests/`:

java -jar karate.jar -t NUME_TEST #pentru testele API
java -jar karate.jar NUME_TEST (ui)   # automatizare UI (aici necesită Chrome și app pe 3838)


## 5. Manual de utilizare

Încarcă un fișier CSV sau Excel din bara laterală. Aplicația detectează automat tipurile coloanelor și propune un atribut sensibil și o variabilă țintă.

### Tab „Date"
- Sumar fișier și tipurile detectate per coloană.
- Preprocesare: elimină rândurile cu valori lipsă, elimină duplicatele, aplică filtre pe coloane la alegerea utilizatorului.
- Previzualizare și editare: poți edita celule direct în tabel și include/exclude rânduri.
- Setare manuală tip coloană: dacă o coloană e detectată greșit (ex. un cod numeric care e de fapt categoric), o poți redefini

### Tab „Analiză Generală"
Apasă „Rulează analiza” (bara laterală), după ce ai ales atributul sensibil și ținta.
- Bias Score global (efect 70% + dezechilibru 30%) cu scală de severitate.
- Alerte distribuționale: asimetrie, valori atipice, subreprezentarea grupurilor.
- Metrici de disparitate:
  - țintă numerică: diferența mediilor, Cohen's d, t-test Welch, ANOVA;
  - țintă binară: SPD (Statistical Parity Difference), Disparate Impact (regula 80%).
- Tabel sumar pe grupuri (descărcabil CSV).

### Tab „Socio-Demografic"
Grupare standardizată a unui indicator financiar în lei (RON):
- vârstă (grupe standard), educație (clasificare ISCED), regiuni (NUTS România);
- comparație cu referințe salariale (media României net/brut, UE, etc.).
- Important de menționat: acest modul presupune valori monetare în lei; pentru alți indicatori comparațiile cu referințele nu au sens, folosiți strict celelalte module

### Tab „Vizualizare"
Grafice interactive (boxplot, density plot, barplot al diferențelor, proporții pentru ținte binare), cu buton de descărcare PNG sub fiecare grafic relevant.

### Tab „Clustere AI"
1. Mapează coloanele la rolurile semantice (sex, vârstă, educație, mediu/origine, venit), opțional adaugă coloane suplimentare. 
2. Sugestie k: (metoda Elbow) pentru numărul optim de clustere.
3. Rulează Clustering (K-Means). Rezultate: scatter PCA 2D, profile detaliate per cluster, analiză de bias intra-cluster, distribuția financiară pe clustere.

### Interpretare AI
În tab-urile relevante, butonul Generează interpretare trimite rezultatele către modelul
LLM local și produce o explicație în română, structurată pe tipuri de bias. Poți pune și
întrebări libere în caseta de chat.

## 6. Note

- Toate calculele rulează local; datele nu sunt trimise în exterior (LLM-ul rulează prin Ollama pe calculatorul propriu).
- Pentru clustering, vizualizarea folosește un eșantion de până la 15.000 de rânduri (randarea interactivă a sute de mii de puncte în browser nu este fezabilă).

## 7. Depanare (probleme frecvente)

În continuare sunt listate problemele întâlnite cel mai des la prima rulare, împreună cu cauza și soluția lor.
Dacă la rularea `source("setup.R")` apare eroarea `cannot open file 'setup.R': No such file or directory`, înseamnă că directorul de lucru al R-ului nu este folderul proiectului. Verifică unde te afli cu `getwd()` și mută-te în folderul corect cu `setwd("calea/catre/proiect")`, conform Pasului 1.
Dacă la pornire apare `python313.dll - Access is denied` (sau orice altă cale care conține `WindowsApps`), reticulate a încercat să folosească versiunea falsă de Python instalată automat de Microsoft Store. Rulează din nou `source("setup.R")`, apoi repornește R și pornește aplicația dintr-o sesiune curată. Aplicația tratează deja această situație prin apelurile `Sys.unsetenv("RETICULATE_PYTHON")` și `use_virtualenv("biasapp")` din `app.R` și `api.R`, dar mediul trebuie selectat înainte de prima inițializare a Python-ului.
Dacă apare `Python is already initialized` la apelul `use_virtualenv`, în aceeași sesiune R s-a inițializat deja un alt Python. Soluția este simplă: repornește R  și pornește aplicația imediat, prima dată, fără a rula alt cod care folosește Python.
Dacă apare `ModuleNotFoundError: pandas` sau `numpy`, mediul `biasapp` nu a fost creat corect. Re-rulează `source("setup.R")`, care șterge și recreează mediul de la zero cu toate pachetele necesare.
Dacă interpretarea AI nu apare sau primești mesajul „Ollama nu este disponibil", serverul Ollama nu rulează ori modelul lipsește. Pornește serverul cu `ollama serve`, verifică modelele instalate cu `ollama list` și, dacă modelul lipsește, descarcă-l cu `ollama pull qwen2.5:14b`.
Dacă aplicația nu pornește pentru că portul 3838 este ocupat, o instanță rulează deja pe acel port. Închide instanța veche sau pornește pe alt port, de exemplu `shiny::runApp(port = 3939)`.
