# git-ssh-gen

Uno script per facilitare la generazione e il caricamento automatico di chiavi SSH su GitHub.  
È pensato per semplificare la configurazione dei dispositivi (es. Raspberry Pi e PC) con una sola email, rendendo più veloce il setup degli ambienti di sviluppo e il push dei repository.

## Obiettivo

- **Automatizzazione:** Lo script genera una chiave SSH usando l'email fornita (o richiedendola interattivamente se non passata come parametro) e utilizza una porzione dell'email per creare un nome univoco per il file della chiave.
- **Facilità d'uso:** Carica automaticamente la chiave pubblica su GitHub tramite le API, eliminando la necessità di farlo manualmente.
- **Standardizzazione:** Permette di configurare rapidamente più dispositivi (es. Raspberry, PC) utilizzando lo stesso metodo e la stessa email, garantendo coerenza e risparmiando tempo.

## Da migliorare

- **Controllo delle dipendenze:**  
  Verificare che siano presenti tutti i comandi necessari (ad es. `ssh-keygen`, `curl`) prima di procedere.
- **Validazione più robusta dell'email:**  
  Potenziare il controllo della validità dell'indirizzo email per gestire anche eventuali casi limite e fornire feedback più dettagliati.
- **Gestione delle chiavi esistenti:**  
  Offrire opzioni per gestire la presenza di chiavi già generate (es. rigenerare, sovrascrivere o utilizzare quella esistente).
- **Feedback e logging:**  
  Integrare un sistema di logging più avanzato (ad esempio, scrivendo su file) per facilitare il debug e l'eventuale monitoraggio delle operazioni.
- **Supporto multi-provider:**  
  Estendere lo script per supportare non solo GitHub, ma anche altri servizi (GitLab, Bitbucket, ecc.) per una maggiore flessibilità.
- **Parametrizzazione avanzata:**  
  Aggiungere opzioni per configurare il tipo di chiave (RSA, Ed25519), la dimensione dei bit, e altri parametri specifici, magari tramite flag o un file di configurazione.

## Possibili opzioni

- **Utilizzo con email come parametro:**  
  Se fornisci l'email come argomento al momento della chiamata, ad esempio:
  ```bash
  ./git-ssh-gen email@mine.it

