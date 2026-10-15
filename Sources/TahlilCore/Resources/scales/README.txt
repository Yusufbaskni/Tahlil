Marka skalası JSON dosyaları

Uygulama önce bu paket içi dosyaları yükler, sonra
~/Library/Application Support/Tahlil/scales/*.json
içindeki dosyalar aynı id ile üzerine yazar veya yeni şablon ekler.

Alanlar:
  id, name, brand, detail, readWaitSeconds, analytes[]
  analyte: id, name, abbreviation, levels[]
  level: valueText, r, g, b (0–255), isTypical

Örnek dosya adları: standard10.json, my-brand-10.json
