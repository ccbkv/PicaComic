# Pica Comic Guide

This document covers the setup steps and controls for each feature. If a setting is hard to find, use the search box at the top of the settings page.

## Contents


- [AI Translation](#ai-translation)
  - [Setup](#setup)
  - [Target languages](#target-languages)
  - [Source languages and recognition models](#source-languages-and-recognition-models)
  - [Custom translation scripts](#custom-translation-scripts)
  - [Enabling](#enabling)
  - [Controls while reading](#controls-while-reading)
  - [Adjusting results](#adjusting-results)
  - [Performance and usage](#performance-and-usage)
  - [Things to know](#things-to-know)


<!--anchor:translation-target-->
### Target languages

"Target language" includes Simplified Chinese, Traditional Chinese, English, Japanese, Korean, French, German, Spanish, Russian and Vietnamese. You can add a language that is not listed:

1. Settings → AI Translation → "Custom languages" → "+" next to "Target languages".
2. "Language name": the AI model translates into this name. Write it in that language, such as `ไทย` or `Bahasa Indonesia`.
3. "Language code": sent to Google Translate and translation scripts, such as `th`, `id` or `pt-BR`. Use a code your service supports.
4. Save, then select it under "Target language".

- Translated pages are stored by language code, so a code cannot be changed after it is added. The name can be changed at any time.
- Removing a custom language does not delete pages already translated into it; adding the same code again brings them back.
- Built-in languages cannot be removed or changed. The custom list travels with your backups across devices.
- Source languages are extended in the next section.
- Translations are laid out left to right, so right-to-left languages such as Arabic or Hebrew may not display correctly.

<!--anchor:translation-source-->
### Source languages and recognition models

Built-in source languages and the recognition model each uses:

| Source language | Recognition model |
| --- | --- |
| Japanese | Japanese model (~460 MB), horizontal and vertical text |
| Simplified Chinese | Chinese (Simplified + Traditional) model; the Chinese / Latin model if that is not downloaded |
| Traditional Chinese | Chinese (Simplified + Traditional) model (~17 MB), required |
| English | English model |
| Korean | Korean model |

- The Chinese / Latin model (~11 MB) only covers common Simplified characters and lacks about 3,800 Traditional ones, so Traditional comics come out with wrong characters. The Chinese (Simplified + Traditional) model covers about 18,000 characters, reads both scripts and also vertical Chinese; once downloaded, Simplified Chinese uses it too.
- "Auto detect" tells Simplified and Traditional apart, so a Traditional comic is translated into Simplified Chinese as usual.
- For a Traditional comic, choose "Traditional Chinese" as the source language. Under "Auto detect", vertical Chinese may be read by the Japanese model as Japanese; choosing the language avoids that.
- If previously opened Traditional pages were recorded as having no text to translate, first choose the correct source language and prepare its model, then long-press "Pre-translate" on the details page → "Re-translate" to recognize them again.

**Model size and accuracy**

A larger model knows more characters and fonts, so it reads more accurately; the cost is a bigger download, a slower first load, more memory and more heat on phones. A character missing from the dictionary is always read as a look-alike, so dictionary coverage matters more than size. Character error rates measured on a desktop with rendered Traditional dialogue (real comic lettering and screentone are harder):

| Model | Result |
| --- | --- |
| Chinese / Latin (~11 MB) | ~17% wrong Traditional characters; vertical text unreadable |
| Chinese (Simplified + Traditional) (~17 MB) | No errors on Traditional, Simplified or vertical text |
| PP-OCRv6 small (~21 MB) | Same as above, slightly slower |
| PP-OCRv6 tiny (~4.5 MB) | About 3x faster, ~18% wrong Traditional characters |

**Adding another source language**

1. Settings → AI Translation → "Custom languages" → "+" next to "Source languages".
2. Enter a language name and code (such as `fr`, `ru`, `th`).
3. Enter the recognition model link (.onnx) and character dictionary link (.txt), or use "Fill in a tested model" for Latin script, Cyrillic or Thai.
4. Saving reads the file sizes; the download starts after you confirm. Models over 100 MB get an extra warning.

- Only PP-OCR text recognition models (CTC) in ONNX format work, together with the character dictionary they were trained with. Paddle, MNN or PyTorch files and encoder-decoder models such as manga-ocr do not.
- "Input height": 48 for PP-OCRv3 and later, 32 for older models.
- After download the model is run once; if it cannot run, is not a recognition model, or its class count does not match the dictionary, the files are deleted and the reason is shown.
- Custom source languages must be selected under "Source language"; "Auto detect" only chooses among the built-in languages.
- The language list travels with your backups; model files do not, so each device downloads its own.

**Custom text detection model**

"Text detection model" on the same page can be replaced with your own, shared by all languages. Only PP-OCR text detection models (DBNet) in ONNX format work; tested choices are PP-OCRv5 mobile (~4.8 MB) and PP-OCRv6 small (~9.9 MB). A larger detector finds small or stylized lettering more reliably but is slower on every page. The built-in detector is used until the download finishes.

<!--anchor:translation-script-->
### Custom translation scripts

Use a script for a translation service whose request format, authentication or response does not match OpenAI, or for your own translation gateway. OpenAI-compatible services can use "AI model" directly and do not need a script. A script replaces only the text translation step; text detection and recognition models are still required.

1. Settings → AI Translation → "LLM providers" → add or edit a provider.
2. Choose "Custom translation script" as the service type. Fill in the API URL, API key and model name as your script requires. These three fields are passed to the script as parameters; unused fields can remain empty.
3. Open "Edit translation script" and define `translate(input)`. Start with the offline example below if needed, then tap "Test script".
4. Tap "Save" at the top of the editor, then also "Save" in the provider dialog, and select that provider in the list. Saving the editor or passing a test does not automatically save and activate the provider.

The function receives an object containing:

| Field | Meaning |
| --- | --- |
| `texts` | An array of input strings, possibly from one or several pages |
| `sourceLang` | Source language code, such as `en`, `ja` or `zh`. `auto` means the app has not determined the language yet; your script or service must detect it, or map it to the API's auto-detection parameter |
| `targetLang` | Target language code, such as `zh`, `zh-TW` or `en`, or the code of a custom target language; map language codes as required by your service |
| `glossary` | This comic's existing glossary as `{source: translation}`. The script must pass it to the service or apply it itself to keep names consistent |
| `provider` | The provider dialog's `{url, key, model}`, all strings. The app does not append URL paths or add authentication headers for your script |

Return `{texts: [...], glossary: {...}}`, with `glossary` optional, or return a plain array of strings. There must be exactly one string per input, in the same order. Glossary keys and values must also be strings; returned terms are used in later translations of the comic. Entries that are too long or resemble sentences, URLs or numbers are filtered out. Return a JavaScript object or array directly, without wrapping the result in `JSON.stringify`.

**Offline smoke test**: this makes no network request and only prefixes each input with `[test]`. It checks script execution and the result format; **it does not translate**. The test should display `[test] Hello`. Replace it before using translation while reading.

```javascript
function translate({texts}) {
    // Smoke test only; no translation or network request.
    return {texts: texts.map(text => '[test] ' + text)};
}
```

**HTTP integration example**: this assumes your service accepts `texts`, `source`, `target`, `model` and `glossary`, and returns `{"translations":[{"text":"你好"}],"glossary":{}}`. It demonstrates request and response mapping, not a ready-to-use universal API. Adapt the fields, authentication and language codes to your service's documentation, and enter the full endpoint in the provider's API URL field.

```javascript
async function translate({texts, sourceLang, targetLang, glossary, provider}) {
    const headers = {'Content-Type': 'application/json'};
    if (provider.key) headers.Authorization = 'Bearer ' + provider.key;
    const response = await Network.sendRequest(
        'POST', provider.url, headers,
        JSON.stringify({
            texts, source: sourceLang, target: targetLang,
            model: provider.model, glossary
        })
    );
    if (response.status < 200 || response.status >= 300) {
        throw new Error('HTTP ' + response.status);
    }
    const data = JSON.parse(response.body);
    // Adapt this mapping to your API's response.
    return {
        texts: data.translations.map(item => item.text),
        glossary: data.glossary || {}
    };
}
```

`Network.sendRequest(method, url, headers, data)` makes an HTTP(S) request and returns `response.status` (status code), `response.headers` (headers with array values) and `response.body` (response text). Serialize JSON request bodies and parse JSON responses yourself. Unsuccessful HTTP status codes do not automatically throw a script error; check them as in the example. Standard JavaScript, `JSON`, array operations and `async` / `await` are available. Network requests are the only supported app API; other Venera APIs, such as file, storage and UI operations, are unavailable.

- "Test script" runs the current editor code with `texts: ['Hello']`, `sourceLang: 'en'`, `targetLang: 'zh'`, an empty glossary and the provider parameters from when you opened the editor. A script with network requests really calls the service and may spend credits. Reopen the editor to test updated provider parameters.
- Tests have a 30-second timeout; normal translation calls have a 3-minute timeout. Each synchronous JavaScript execution has a limit of about 1 second. Avoid infinite loops and long synchronous computations; use asynchronous network requests.
- A missing `translate` function, syntax errors, invalid URLs, failed requests, timeouts, wrong translation counts or types, and malformed glossaries all cause failure. First use the offline example to check execution, then check HTTP status, authentication, language codes and response fields. While reading, tap the failure icon for the error and retry.
- Scripts can read the input text, glossary and provider key, and send requests to HTTP(S) addresses chosen by the script. Run only scripts you understand or trust and check their destinations. Store keys in the provider field and use `provider.key`; do not hardcode them in scripts, examples or error messages.
- Script code stays on this device and does not sync to other devices. Add and test the script separately before using the provider on another device.

<!--anchor:translation-enable-->
### Enabling

Translation is enabled per comic, with no global switch, because it spends your own credits. Two entry points:

- Comic detail page → more menu (top right) → "Enable AI translation".
- Reader → Settings → AI Translation → "Translate pages while reading".

Pages are then translated as they are reached, showing the original until each finishes. To translate in advance, use the "Pre-translate" button on the detail page; work runs in the background and progress appears on the Tasks page.

<!--anchor:translation-reading-->
### Controls while reading

- Image icon in the top bar: switch between the translation and the original for comparison, without changing the translation settings.
- Progress ring in the top bar: this page is being translated.
- Red warning icon in the top bar: this page failed; tap to see why and retry.

<!--anchor:translation-adjust-->
### Adjusting results

Long-press the "Pre-translate" button on the detail page to open:

- **Glossary**: review and correct the names and proper nouns learned for this comic. Later translations follow the corrections.
- **Re-translate**: clear this comic's translations and glossary, then translate again.

Other options:

- To redo only some chapters: select them in the chapter picker and use "Re-translate selected".
- If the translation is poorly masked: Settings → AI Translation → Advanced translation settings → "Text removal". "Smart erase" (default) reconstructs the bubble's background and screentone; "Color patch" covers the area with a solid block — faster, with harder edges.

<!--anchor:translation-performance-->
### Performance and usage

Translated text is stored, so a page normally runs OCR and an LLM request only once; re-reading does not spend more credits. Switching between "Smart erase" and "Color patch" only redraws the page from stored text, without repeating OCR or translation. Settings → AI Translation → Help & cleanup → "Clear translation results" frees the space and keeps the language and glossary learned per comic. Results written by older versions using the old cache format are discarded automatically and must be translated again.

If throughput is poor or the provider returns rate-limit errors, adjust "Performance mode" in Settings → AI Translation. The other options below are under "More settings" → "Advanced translation settings" on that page:

| Setting | Effect |
| --- | --- |
| Performance mode | "Save resources" reduces memory and heat; "Balanced" (recommended) suits most devices; "Fast" raises concurrency and battery use. The mode is device-local, so desktop values do not overwrite a phone |
| Pages per pre-translation request | Pages per request. More reduces the request count but increases per-request latency; too many can exceed the model's context |
| Translation request concurrency | Requests in flight at once. Lower it when rate-limited |
| OCR parallelism | Local recognition threads, 0 for automatic. Mobile limits concurrency automatically; the Japanese model uses one worker on mobile. Lower it if the device heats up or stutters |
| Image download concurrency | Images downloaded at once |

Most users do not need "Advanced translation settings"; changing any performance detail switches the mode to "Custom" automatically. Each text line is erased using a tight region and the translated text is kept inside its own area, reducing damage to characters and backgrounds. Complex artwork, very long sentences and unusual layouts can still need a retry or the "Color patch" fallback.

"Translation prompt" replaces the built-in prompt. The built-in one asks for natural dialogue, reuse of already-agreed character names, and a report of proper nouns new to the page — requirements that cost input tokens on every request. A small self-hosted model that cannot afford them can be given a shorter prompt, at the cost of translation quality and consistent naming across pages. When writing your own:

| Placeholder | Replaced with |
| --- | --- |
| `$target` | The target language name, e.g. "English"; for a custom target language, the name entered when adding it |

Two things must stay in the prompt or the feature stops working. First, ask the model to output only a JSON object like `{"lines":[{"id":0,"text":"translation"}]}` with each id appearing exactly once — the app uses those ids to put each translation back in its own bubble, and a reply it cannot parse fails the page. Second, if you want names to stay consistent, tell the model to reuse the renderings given in the `glossary` field and to return newly seen proper nouns in a `names` field. Clearing the field and saving restores the built-in prompt. The setting travels with your backups across devices.

<!--anchor:translation-limits-->
### Things to know

- Marked experimental: recognition and translation can both fail, most visibly on long text and unusual layouts.
- The Japanese model is large because vertical manga text currently has only one reliable recognition option.
- Inference is CPU-only, so pre-translating on mobile causes noticeable heat and battery drain. Run it while charging.

<!--anchor:cache-directory-->
