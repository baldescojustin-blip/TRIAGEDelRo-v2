"""
GENERATE_REPORTS.PY - Builds data/reports.csv (the local Filipino/Bikol
barangay-report training set) from hand-written templates.

Run: python generate_reports.py
Output: data/reports.csv  (columns: report_text, category, severity, language)

Languages covered:
  - tagalog : Filipino/Tagalog (incl. Taglish) reports
  - bikol   : Bikol / Bikol-English reports

IMPORTANT — BIKOL DATA CAVEAT:
The Bikol templates below were drafted by an AI assistant using vocabulary
cross-checked against common Bikol-Naga (Central Bikol) terms, but the author
is NOT a certified Bikol speaker. Before this data is used to train a model
that you present at defense, have a native/fluent Bikol speaker review the
`bikol_data` dict below for correctness (grammar, word choice, natural
phrasing). Treat this as a first draft, not verified ground truth.
"""

import pandas as pd
import random

random.seed(42)

# ─── TAGALOG/TAGLISH BASE TEMPLATES PER CATEGORY + SEVERITY ─────────────────

tagalog_data = {
    ("Flooding", "High"): [
        "Nagbaha na sa aming bahay lahat nalubog ang gamit",
        "May nakulong na tao sa loob ng bahay hindi makalabas dahil sa baha",
        "Mataas na ang tubig sa aming lugar halos hanggang dibdib na",
        "Ang baha ay umabot na sa bubungan ng mababang bahay dito sa amin",
        "Maraming pamilya ang naipit sa baha hindi makaalis ng bahay",
        "Puno na ang ilog at umaapaw na sa mga bahay sa tabi ng ilog",
        "Naanod ang sasakyan namin dahil sa lakas ng agos ng tubig",
        "Mga bata at matatanda naipit sa baha kailangan ng rescue",
        "Biglang bumaha ang kanal umabot na ang tubig sa loob ng bahay namin",
        "Sira na ang dike hindi na kaya ng tubig tumatalab na sa mga kabahayan",
        "Dalawang bahay na naanod sa baha kailangan agad ng tulong",
        "Hindi na kami makalabas ng bahay puno na ang daan ng tubig",
        "Lumagpas na ang baha sa baywang antas kailangan na ng pagtulong",
        "Nagtayo na ng emergency shelter pero may naiwan pang tao sa baha",
        "Ang ilog ay pumatak na sa critical level paabot na sa mga kabahayan",
        "Nasira ang tulay dahil sa lakas ng baha hindi na madaraanan",
        "Maraming pamilya ang nawalan ng tirahan dahil sa malaking baha",
        "Umabot na ang baha sa loob ng classroom at opisina ng barangay",
        "Nagtaas ng babala ang weather bureau malakas pang ulan darating",
        "Ang mga residente ay lumikas na pero may natira pang matatanda",
    ],
    ("Flooding", "Medium"): [
        "Maliit lang ang baha pero lumalaki na kailangan bantayan",
        "Maraming basura sa estero nagdudulot ng baha sa paligid",
        "Ang drainage dito sa amin ay puno na ng basura kaya nagbabaha",
        "Nagbabaha sa kalsada tuwing umuulan hindi na maraanan",
        "Bumabaha sa basement ng building kapag malakas ang ulan",
        "Ang mga kalye dito ay palaging nababaha tuwing bagyo",
        "Ang ilang parte ng barangay ay may mababaw na baha",
        "Naestrangle ang daloy ng tubig sa kanal kaya nagbabaha",
        "Ang estero sa amin ay lagi nang umaapaw kapag umuulan",
        "Palagi kaming nababaha dahil sa mataas na lugar sa paligid namin",
        "Nagsimula ng bumaha sa mababang lugar ng barangay",
        "Ang drainage system ay sira na kaya palaging nagbabaha",
        "Bumabaha ang kalsada at may peligro sa mga motorista",
        "Mababaw ang baha pero lumalamig na ang temperatura pwede pa lumaki",
        "Ang creek sa likod ng barangay ay umaapaw na kapag malakas ang ulan",
    ],
    ("Flooding", "Low"): [
        "Maliit lang ang baha sa kalsada pero gusto lang ireport",
        "Konting tubig sa labas ng bahay wala naman malaking epekto",
        "Nabasa lang ang kalsada sa harap hindi naman malubha",
        "May konting genggeng sa daan dahil sa ulan kanina",
        "Maliit na baha sa ilalim ng tulay gusto lang malaman ng barangay",
        "Umaapaw ng kaunti ang kanal pero hindi pa malaki ang epekto",
        "Nabasa ang tawiran pero hindi naman delikado",
        "Konting tubig sa likod ng bahay sanay na kami pero ireport ko lang",
    ],
    ("Medical", "High"): [
        "May nasugatan sa aming kapitbahay kailangan ng tulong",
        "May taong nahimatay sa kalsada kailangan ng ambulansya",
        "Naaksidente ang aking kapitbahay kailangan ng agad na tulong medikal",
        "May bata na binugbog kailangan ng medical attention agad",
        "Nahulog ang isang residente mula sa hagdan hindi na makagalaw",
        "May matandang babaeng biglang nanghina sa labas ng bahay niya",
        "Tinamaan ng poste ng kuryente ang isang lalaki unconscious na siya",
        "Naputol ang daliri ng isang bata sa aksidente kailangan ng ospital",
        "May tao na sinagasaan ng sasakyan nasaktan at kailangan ng rescue",
        "Nagkaroon ng seizure ang aking kapit bahay hindi siya makapag-abot ng tulong",
        "May buntis na manganganak na kailangan ng agad na sasakyan papunta ospital",
        "Nasunog ang kamay ng bata habang naglalaro malapit sa kalan kailangan ng tulong",
        "May matanda na hirap huminga sinasabing masakit ang dibdib niya",
        "Biglang natumba ang lalaki sa kalsada walang makatulong sa kanya",
        "May bata na nalunod sa mababaw na tubig kailangan agad ng medikal",
    ],
    ("Medical", "Medium"): [
        "Maraming residente ang nagkakasakit posibleng dengue dapat mag-fumigate",
        "Maraming bata ang may lagnat at ubo sa aming purok",
        "Maraming pasyente ang nagrereklamo ng sakit na posibleng food poisoning",
        "May residente na may mataas na lagnat at kailangan ng medical check",
        "Ang matanda sa kanto ay may matagal nang sugat na hindi gumagaling",
        "Maraming nagkakasakit sa aming lugar mula nang bumuhos ang baha",
        "May suspetsa na dengue outbreak sa aming barangay maraming nagrereklamo",
        "Kailangan ng libreng medical mission ang aming barangay maraming pasyente",
        "Ang aming kapit bahay ay matagal nang hindi kumakain kailangan ng tulong",
        "May bata na allergic at nangangailangan ng medisin hindi sila makabili",
    ],
    ("Medical", "Low"): [
        "Gusto ko lang ireport na maraming lamok sa aming lugar",
        "Kailangan ng vitamins ang mga bata sa aming purok",
        "May nagrereklamo ng sakit ng ulo sa init ng panahon ngayon",
        "Gusto ipaalala na kailangan ng rabies vaccine sa mga aso dito",
    ],
    ("Fire", "High"): [
        "May sunog sa bahay ng kapitbahay namin tulong naman",
        "Nasusunog ang bodega sa tabi ng aming bahay kailangan ng BFP",
        "Malaking sunog sa palengke lumalaki na ang apoy kailangan ng tulong",
        "Nasunog ang apat na bahay sa aming sityo kailangan ng rescue",
        "Malaki ang sunog sa pabrika apoy lumalabas na sa bubong",
        "Nakita ko ang usok mula sa bahay na walang tagaroon posibleng susunog",
        "Nagsimula sa kalan ang sunog mabilis na kumalat sa ibang bahay",
        "Ang LPG tank ay naputok at nagdulot ng sunog sa paligid",
        "Nagliliyab ang bahay ng aming kababarangay kailangan ng fire truck",
        "May sunog sa informal settler area doon sa kabila maraming nasusunog",
        "Apoy na lumabas sa transformer nagdulot ng sunog sa tabi nitong bahay",
        "Sumonod ang sunog mula sa isang bahay patungo sa mga kapitbahay namin",
        "Malaking sunog sa lumber yard apoy papalaki na",
        "Nasusunog ang tindahan may mga taong naiipit sa loob",
        "May sunog sa talipapa mabilis kumakalat dahil sa hangin",
    ],
    ("Fire", "Medium"): [
        "May napansing usok sa dumpsite baka sumasamang basura",
        "Nasusunog ang basura sa likod ng kalsada may usok na lumalagay",
        "May maliit na sunog sa vegetable stall nabugaw na pero may natitira",
        "Ang mga bata ay naglaro ng posporo malapit sa mga kahoy posibleng masunog",
        "Nasunog ang kaunting pader ng bahay kontrol na pero kailangan pa rin suriin",
        "Nakakita kami ng apoy sa abandonadong bahay posibleng sinusunog ng vandals",
        "May maliit na sunog sa kangkungan sa likod ng barangay hall",
    ],
    ("Fire", "Low"): [
        "Nasunog ang mga tuyong dahon sa likod ng paaralan nabugaw na",
        "May konting usok mula sa kalan ng kapitbahay wala naman malaking problema",
        "Nasunog ang mga lumang papel sa labas ng bahay naapula na ng tubig",
        "Nasunog ang basura sa tambak matagal nang ganito gusto ko lang ireport",
    ],
    ("Road Hazard", "High"): [
        "Nahulog ang puno sa gitna ng kalsada hindi madaraanan",
        "Bumagsak ang malaking bato mula sa bundok naharang ang daan",
        "Nalaglag ang overpass bridge component sa kalsada delikado sa mga sasakyan",
        "Nahulog ang malaking poste sa gitna ng highway pakiayos na",
        "Nasira ang kalsada matapos ang baha may malaking butas sa daan",
        "Bumagsak ang lupa mula sa tabi ng kalsada naharang na ang daanan",
        "Ang aspalto sa harap ng eskwelahan ay biglang lumubog may malaking hukay",
        "May nahulog na container van sa kalsada delikado sa mga sasakyan",
        "Bukas na ang manhole cover sa gitna ng daan nakita ko na ang ilang nadaanan",
        "Nahulog ang malaking sanga ng puno sa kalsada naputol ang linya ng kuryente",
    ],
    ("Road Hazard", "Medium"): [
        "May malaking hukay sa kalsada na mapanganib lalo na sa gabi",
        "Sira na ang speed bump sa harap ng eskwelahan mapanganib sa mga bata",
        "Hindi gumagana ang traffic light sa intersection mapanganib",
        "Maraming butas sa daan sa aming sityo kailangan ng ayos",
        "Ang kalsada sa aming barangay ay lubak lubak na mapanganib sa motorsiklo",
        "Ang daanan sa tulay ay makitid na at baka bumagsak na ang isang parte",
        "May malalaking bato sa kalsada pagkatapos ng ulan delikado sa gabi",
        "Ang guardrail sa mataas na daan ay sira na at mapanganib",
    ],
    ("Road Hazard", "Low"): [
        "Maliliit na butas sa kalsada gusto ko lang ireport para maayos",
        "Ang linya sa kalsada ay hindi na kita kailangan ng bagong pintura",
        "Ang signage sa kanto ay nahulog na kailangan ng kapalit",
        "Konting dumi sa kalsada pagkatapos ng pista gusto ko lang ireport",
        "Ang sidewalk sa aming lugar ay puno na ng mga nakaradyong halaman",
    ],
    ("Utility", "High"): [
        "Bumagsak ang poste ng kuryente sa harap ng aming bahay",
        "Naputol ang power line at bumagsak sa kalsada delikado sa mga tao",
        "Walang tubig na iniinom sa aming lugar tatlong araw na ito",
        "Naputol ang main water pipe lahat kami walang tubig",
        "Naputol ang linya ng kuryente nahulog sa may basang daan mapanganib",
        "Nahulog ang transformer malapit sa bahay may electric hazard",
        "Naputol ang gas line malapit sa mga bahay mapanganib sa pagsabog",
        "Bumagsak ang poste sa gitna ng kalsada may nakabitin na linya",
    ],
    ("Utility", "Medium"): [
        "Nagreklamo ang mga residente dahil walang tubig tatlong araw na",
        "Lagi na kaming walang kuryente sa gabi pumunta na kami sa barangay hall",
        "Sira na ang street light sa aming kalsada mapanganib sa gabi",
        "Ang water pressure sa aming lugar ay napakababa halos walang tubig",
        "Nagko-korslot ang wiring sa poste sa labas ng aming bahay",
        "Ang drainage sa aming lugar ay sira na palagi kaming nababaha",
        "Walang tubig kami tuwing umaga dapat ay may tubig",
    ],
    ("Utility", "Low"): [
        "Gusto ko lang ireport na maluwag ang takip ng drainage sa aming daan",
        "Ang street light sa aming lugar ay naputulan ng ilaw gusto ko lang ireport",
        "Ang poste sa likod ng bahay ay medyo yumuko na gusto ko lang ipaalam",
        "Walang kuryente ngayon kaya nagrereport lang kung may nangyari",
        "Gusto ko lang ireport na baka kailangan na ng bagong tubig pipes dito",
    ],
    ("Landslide", "High"): [
        "May pagguho ng lupa sa taas ng bundok naharang ang daan pababa",
        "Bumagsak ang lupa mula sa mataas na bahagi patungo sa mga bahay sa ilalim",
        "Malaking landslide sa kabundukan naiipit ang ilang pamilya sa ibaba",
        "Nagguho ang lupa sa gilid ng kalsada sa bundok peligroso sa mga sasakyan",
        "Biglang bumagsak ang malaking bahagi ng bundok malapit sa mga bahay",
        "Ang landslide ay sumakop sa dalawang bahay kailangan ng rescue agad",
        "Nagguho ang lupa matapos ang malakas na ulan maraming naapektuhan",
        "May pagguho ng lupa sa estero naharang na ang daloy ng tubig",
        "Bumagsak ang malaking bato mula sa bundok tumama sa bahay ng kapitbahay",
        "Nagguho ang gilid ng kalsada sa bundok hindi na ligtas ang daanan",
    ],
    ("Landslide", "Medium"): [
        "Nagsisimulang gumuhit ang lupa sa bundok sa aming lugar babantayan",
        "May nakita kaming bitak sa lupa sa mataas na lugar posibleng magguho",
        "Ang gilid ng kalsada sa bundok ay nagpapaluwag na baka magguho",
        "Maraming nahulog na bato mula sa taas ngayong tag-ulan kailangan bantayan",
        "Ang lupa sa gilid ng bahay namin ay lumalagpas na posibleng magguho",
        "Ang bundok sa taas ay nagpapakita ng ilang bitak posibleng landslide",
    ],
    ("Landslide", "Low"): [
        "May konting guho ng lupa sa tabi ng kalsada maliit lang naman",
        "Nahulog ang kaunting lupa sa drainage gusto ko lang ireport",
        "May nakita kaming mga bato sa kalsada baka nanggaling sa bundok",
    ],
    ("Power Hazard", "High"): [
        "May live wire na nahulog sa kalsada mapanganib sa lahat",
        "May electric shock ang isang bata sa tapat ng aming bahay",
        "Naputol ang high tension wire at bumagsak sa palengke",
        "May nagko-korslot na linya ng kuryente sa gitna ng basa na kalsada",
        "Nahulog ang transformer sa may palengke may apoy na lumalabas",
        "Ang nakababa na wire sa bukid ay nakasalpak sa basa na puno mapanganib",
        "May live wire na nakalagay sa gilid ng daan nakikita ko ang spark nito",
        "Ang kuryente ay lumalagyan ng apoy sa poste malapit sa paaralan",
    ],
    ("Power Hazard", "Medium"): [
        "Ang mga linya ng kuryente sa aming lugar ay masyadong mababa delikado",
        "May lumang transformer sa aming lugar posibleng mapanganib na",
        "Ang wiring sa isang bahay ay luma na at baka magkorslot",
        "Nakita ko ang spark sa linya ng kuryente sa harap ng palengke",
        "Ang mga linya ay magkadikit na sa kalye mapanganib sa mga motorsiklo",
    ],
    ("Power Hazard", "Low"): [
        "Ang ilaw sa aming sityo ay kumukurap na baka may problema sa linya",
        "May konting spark sa lumang socket sa aming barangay hall",
        "Gusto ko lang ireport na ang aming poste ay medyo lumang lumuma na",
    ],
    ("Structural", "High"): [
        "Ang bahay ng aming kapitbahay ay malapit nang bumagsak kailangan lumikas",
        "Ang gusali sa aming lugar ay may malalaking bitak sa pader mapanganib",
        "Bumagsak ang bubong ng abandonadong gusali may napit na tao sa loob",
        "Ang tulay sa aming lugar ay may malaking bitak mapanganib ang pagtawid",
        "Ang lumang gusali ay gumuho na sa isang parte kailangan ng rescue",
        "Ang bahay ay gumuho matapos ang lindol may napit na pamilya",
        "Biglang bumagsak ang kisame ng paaralan may mga bata sa loob",
        "Ang retaining wall sa aming lugar ay gumuho na kailangan ng ayos",
    ],
    ("Structural", "Medium"): [
        "Ang lumang barangay hall ay may mga bitak na sa pader kailangan na suriin",
        "Ang tulay sa aming barangay ay mababa na at baka hindi na matibay",
        "Maraming bitak ang pader ng aming eskwelahan posibleng delikado",
        "Ang waiting shed sa kanto ay gumuguho na kailangan ng bagong istruktura",
        "Ang fence ng barangay basketball court ay tilt na posibleng mabuwal",
    ],
    ("Structural", "Low"): [
        "Ang bakod ng parke sa amin ay may sira na dapat na ayusin",
        "Ang pintuan ng sityo hall ay sira na mahirap buksan",
        "May bitak sa plasa ng barangay maliit lang naman pero gusto ko lang ireport",
    ],
    ("Security", "High"): [
        "May nagtatalik ng barilan sa aming lugar takot na ang mga residente",
        "Nakita ko ang isang taong may hawak na patalim nagbabanta sa mga tao",
        "May nang-aagaw ng bag sa aming lugar maraming beses nang nangyari",
        "Nakita ko ang isang suspetsa na taong nagtatago sa likod ng building",
        "May nagnakaw ng motorsiklo sa aming barangay kararating lang ng insidente",
        "May nag-aaway at gumagamit ng armas sa palengke kailangan ng pulis agad",
        "Nakita ang isang lalaki na bumabasag ng bintana ng mga bahay sa gabi",
        "May nagtatalik ng away ng grupo sa kanto ng aming barangay mapanganib",
    ],
    ("Security", "Medium"): [
        "Maraming adik na nakikita sa aming lugar gabi gabi kailangan ng aksyon",
        "May grupo na nagrerekolekta ng lagay sa mga negosyante sa palengke",
        "Maraming beses nang nagnakaw ng gulay sa aming sityo kailangan ng aksyon",
        "Ang mga kabataan ay nagtitipon sa gabi at may ingay na naririnig",
        "May pinaghihinalaang drug den sa katabing bahay kailangan ng imbestigasyon",
        "Ang aking kapitbahay ay nagrereklamo ng paulit ulit na pagnanakaw",
    ],
    ("Security", "Low"): [
        "Maingay ang mga kabataan sa kanto gabi gabi hindi makatulog",
        "Gusto ko lang ireport na may mga estranyo na nakikita sa aming lugar",
        "May nagtatambay sa harap ng aming bahay gabi gabi gusto ko lang ireport",
        "Ang aming sityo ay kulang sa ilaw sa gabi posibleng hindi ligtas",
    ],
    ("Infrastructure", "High"): [
        "Bumagsak ang malaking bahagi ng tulay sa aming lugar delikado",
        "Nasira ang pangunahing kalsada at hindi na madaraanan ng mga sasakyan",
        "Ang sewage system ay sumabog at nagdulot ng polusyon sa mga bahay",
        "Bumagsak ang retaining wall ng kalsada sa bundok napit ang mga sasakyan",
        "Ang drainage pipe ay sumabog at may umaapaw na dumi sa kalsada",
        "Ang overpass ay may malaking bitak at delikado na sa mga gumagamit",
    ],
    ("Infrastructure", "Medium"): [
        "Ang kalsada sa aming sityo ay lubak lubak na at sira ang drainage",
        "Ang tulay ay may malaking butas na sa gitna delikado sa mga bata",
        "Sira ang mga manhole cover sa aming lugar delikado sa mga nagtatakbo",
        "Ang mga bangketa sa aming lugar ay hindi na magamit sira na lahat",
        "Ang dam sa aming lugar ay may bitak na kailangan suriin bago pa lumaki",
    ],
    ("Infrastructure", "Low"): [
        "Ang pintuan ng barangay basketball court ay sira na hindi masara",
        "Ang mga bench sa plasa ay sira na kailangan ng bagong bench",
        "Gusto ko lang ireport na ang drainage sa aming sityo ay puno ng basura",
        "Ang mga sign sa kalsada ay halos hindi na nababasa kailangan ng kapalit",
    ],
    ("Food", "High"): [
        "Maraming tao ang nagkasakit matapos kumain sa canteen ng barangay",
        "May food poisoning na naranasan ang maraming residente mula sa iisang tindahan",
        "Ang tubig na ininom ng mga bata ay may kakaibang amoy posibleng kontaminado",
        "Maraming residente ang nagsuka at nagtatae matapos sa fiesta salo salo",
        "Ang inuming tubig ng barangay ay may amoy na hindi normal kailangan suriin",
    ],
    ("Food", "Medium"): [
        "May tindahan sa palengke na nagbebenta ng masamang karne kailangan suriin",
        "Ang mga pagkain sa canteen ay hindi maayos na nakaimbak posibleng masama",
        "Maraming residente ang hindi kumakain dahil sa tagtuyot wala silang pagkain",
        "Kailangan ng food assistance ang maraming pamilya sa aming barangay",
        "Ang isda sa palengke ay matagal na at may amoy na kailangan suriin",
    ],
    ("Food", "Low"): [
        "Gusto ko lang ireport na may nagbebenta ng expired na pagkain sa tindahan",
        "Kailangan ng feeding program para sa mga batang walang maabot na pagkain",
        "Ang aming sityo ay kailangan ng livelihood para hindi sila magutom",
    ],
    ("Animal", "High"): [
        "May asong gala na kagat ng kagat ng mga tao sa aming lugar mapanganib",
        "Kinagat ng aso ang isang batang nasa daan kailangan ng medikal na tulong",
        "May ulol na aso sa aming lugar kinagat na ang tatlong tao kailangan tulungan",
        "Nakita ang malaking ahas sa loob ng bahay ng kapitbahay namin kailangan ng rescue",
    ],
    ("Animal", "Medium"): [
        "Maraming asong gala sa aming lugar nakakadismaya at delikado sa mga bata",
        "May mabahong amoy mula sa patay na hayop sa ilog kailangan alisin",
        "Ang mga baboy na gala sa kalsada ay nagdudulot ng panganib sa mga sasakyan",
        "Maraming daga na lumalabas sa aming lugar mula nang bumaha",
        "Ang mga alagang aso ng kapitbahay ay palaging umaatake sa mga dumaan",
    ],
    ("Animal", "Low"): [
        "Gusto ko lang ireport na maraming asong gala sa aming purok",
        "Ang mga pusa at aso sa aming lugar ay walang bakuna dapat ayusin",
        "May nakita kaming ahas sa tabi ng ilog maliit lang naman ireport ko lang",
    ],
}

# ─── BIKOL / BIKOL-ENGLISH BASE TEMPLATES ───────────────────────────────────
# DRAFT — needs native-speaker review before being trusted for defense. See
# module docstring above.

bikol_data = {
    ("Flooding", "High"): [
        "Nagbaha na sa samuyang harong, gabos na gamit nalubugan na",
        "Igwa nin mga tawong nasyerak sa harong huli sa baha, dai makaluwas",
        "Mataas na an baha sa samuyang lugar, halos sa daghan na kan mga tawo",
        "Dakul na pamilya an nagkaipit sa baha, kaipuhan nin rescue tulos",
        "Naanod an samuyang sasakyan huli sa kusog kan sulog nin tubig",
        "Biglang naghabon an baha, nakaabot na sa laog kan harong mi",
        "Nagkagaba an tulay huli sa kusog kan baha, dai na madadaanan",
        "Naghihilaw an salog asin nag-aalsa na sa mga harong sa gilid",
    ],
    ("Flooding", "Medium"): [
        "Sadit sana an baha pero naghihilaw na, kaipuhan bantayan",
        "Dakul na basura sa kanal, ini an dahilan kan pagbaha digdi",
        "Naghihilaw an baha sa kalsada tuwing nag-uuran",
        "An salog digdi sa amon parati nang nag-aalsa pag kusog an uran",
        "Naghihilaw an baha sa mababang parte kan barangay",
        "Gaba na an drainage kaya parati kaming binabaha",
    ],
    ("Flooding", "Low"): [
        "Sadit sanang baha sa kalsada, gusto ko sanang i-report",
        "Nabasa sana an atubangan kan harong, dai naman grabe",
        "May konting tubig sa gilid kan tulay huli sa uran",
        "Naghihilaw nin dikit an kanal pero dai pa grabe",
    ],
    ("Medical", "High"): [
        "May nasakitan sa samuyang kataed, kaipuhan tulos nin tabang",
        "May tawong nawaran nin malay sa kalsada, kaipuhan nin ambulansya",
        "Naaksidente an sakuyang kataed, kaipuhan nin dagos na tabang medikal",
        "May aking binugbog, kaipuhan nin atensyon medikal ngunyan man",
        "Nahulog sa hagdan an sarong residente, dai na makahiro",
        "May gurang na babaeng biglang naluya sa luwas kan harong niya",
    ],
    ("Medical", "Medium"): [
        "Dakul na residente an naghehelang, tibaad dengue, kaipuhan nin fumigation",
        "Dakul na aki an may lagnat asin ubo sa samuyang purok",
        "Dakul na nagrereklamo nin helang na tibaad food poisoning",
        "May residenteng may mataas na hilanat, kaipuhan nin check-up",
        "An gurang sa kanto igwa nin daan nang samad na dai naghahayad",
    ],
    ("Medical", "Low"): [
        "Gusto ko sanang i-report na dakul na lamok sa samuyang lugar",
        "Kaipuhan nin bitamina an mga aki sa samuyang purok",
        "May nagrereklamo nin sakit nin payo huli sa kainit ngunyan",
    ],
    ("Fire", "High"): [
        "May sunog sa harong kan kataed mi, tabangan man kami",
        "Nagkakalayo an bodega sa gilid kan samuyang harong, kaipuhan nin BFP",
        "Dakulang sunog sa palengke, nagdadakula pa an kalayo, kaipuhan nin tabang",
        "Apat na harong an nasunog sa samuyang sityo, kaipuhan nin rescue",
        "Nagkalayo an pabrika, an kalayo nag-aabot na sa atop",
        "Naghali sa kalan an sunog, luway-luway nag-aabot sa ibang harong",
    ],
    ("Fire", "Medium"): [
        "May naheling na aso sa dumpsite, tibaad may nagkakalayo na basura",
        "Nagkakalayo an basura sa likod kan kalsada, may aso na nagluluwas",
        "May sadit na sunog sa vegetable stall, nabugaw na pero igwa pang natada",
        "Nagkalayo an sadit na pader kan harong, kontrolado na pero kaipuhan pa suhayan",
    ],
    ("Fire", "Low"): [
        "Nasunog an mga alang na dahon sa likod kan eskwelahan, nabugaw na",
        "May konting aso hali sa kalan kan kataed, dai naman grabe",
        "Nasunog an mga daan na papel sa luwas kan harong, napalong na kan tubig",
    ],
    ("Road Hazard", "High"): [
        "Nahulog an kahoy sa tahaw kan kalsada, dai na madadaanan",
        "Nahulog an dakulang gapo hali sa bukid, nakaharang sa dalan",
        "Nahulog an dakulang poste sa tahaw kan highway, ayuson na tabi",
        "Nagaba an kalsada pagkatapos kan baha, igwa nin dakulang lungag",
        "Nahulog an daga hali sa gilid kan kalsada, nakaharang na an dalan",
    ],
    ("Road Hazard", "Medium"): [
        "Igwa nin dakulang lungag sa kalsada na peligroso, orog na sa banggi",
        "Gaba na an speed bump sa atubangan kan eskwelahan, peligroso sa mga aki",
        "Dai nagfufunction an traffic light sa interseksyon, peligroso",
        "Dakul na lungag sa dalan sa samuyang sityo, kaipuhan ayuson",
    ],
    ("Road Hazard", "Low"): [
        "Sasadit na lungag sa kalsada, gusto ko sanang i-report para maayos",
        "An linya sa kalsada dai na naheheling, kaipuhan bagong pintura",
        "Nahulog an signage sa kanto, kaipuhan nin kapalit",
    ],
    ("Utility", "High"): [
        "Nahulog an poste nin kuryente sa atubangan kan samuyang harong",
        "Naputol an linya nin kuryente asin nahulog sa kalsada, peligroso",
        "Daing tubig na maiinom sa samuyang lugar sa tulong aldaw na ini",
        "Naputol an pangenot na tubo nin tubig, gabos kami daing tubig",
    ],
    ("Utility", "Medium"): [
        "Nagrereklamo an mga residente huli ta daing tubig sa tulong aldaw na",
        "Parati kaming daing kuryente sa banggi, nagduman na kami sa barangay hall",
        "Gaba na an street light sa samuyang kalsada, peligroso sa banggi",
        "An water pressure digdi hababa na gayod, halos daing tubig",
    ],
    ("Utility", "Low"): [
        "Gusto ko sanang i-report na luag an takop kan drainage sa samuyang dalan",
        "An street light sa samuyang lugar naputulan nin ilaw, gusto ko sanang i-report",
        "Daing kuryente ngunyan kaya nagrereport sana kun may nangyari",
    ],
    ("Landslide", "High"): [
        "Igwa nin pagkagaba kan daga sa itaas kan bukid, nakaharang an dalan pasiring digdi",
        "Nahulog an daga hali sa mataas na parte pasiring sa mga harong sa ibaba",
        "Dakulang landslide sa kabukiran, may mga pamilyang naipit sa ibaba",
        "Nagkagaba an daga sa gilid kan kalsada sa bukid, peligroso sa mga sasakyan",
        "Biglang nahulog an dakulang parte kan bukid harani sa mga harong",
    ],
    ("Landslide", "Medium"): [
        "Nagpoon nang maggaba an daga sa bukid sa samuyang lugar, babantayan",
        "May naheling kaming pitak sa daga sa mataas na lugar, tibaad maggaba",
        "An gilid kan kalsada sa bukid naluluwag na, tibaad maggaba",
        "Dakul na gapo an nahulog hali sa taas ngunyan na tag-uran",
    ],
    ("Landslide", "Low"): [
        "May sadit na pagkagaba kan daga sa gilid kan kalsada, sadit sana man",
        "Nahulog an konting daga sa drainage, gusto ko sanang i-report",
        "May naheling kaming mga gapo sa kalsada, tibaad hali sa bukid",
    ],
    ("Power Hazard", "High"): [
        "May nahulog na buhay na alambre sa kalsada, peligroso sa gabos",
        "May electric shock an sarong aki sa atubangan kan samuyang harong",
        "Naputol an high tension wire asin nahulog sa palengke",
        "Nahulog an transformer harani sa palengke, may kalayong naluluwas",
    ],
    ("Power Hazard", "Medium"): [
        "An mga linya nin kuryente digdi hababa na gayod, peligroso",
        "May daan na transformer digdi, tibaad peligroso na",
        "An wiring kan sarong harong daan na, tibaad magkorto-sirkito",
    ],
    ("Power Hazard", "Low"): [
        "An ilaw sa samuyang sityo nagkikirap-kirap na, tibaad may problema sa linya",
        "May konting spark sa daan na socket sa samuyang barangay hall",
        "Gusto ko sanang i-report na an samuyang poste medyo naghihiro na",
    ],
    ("Structural", "High"): [
        "An harong kan samuyang kataed haros matumba na, kaipuhan lumihis",
        "An gusali sa samuyang lugar igwa nin dakulang pitak sa lanob, peligroso",
        "Natumba an atop kan alang na gusali, may naipit na tawo sa laog",
        "An tulay sa samuyang lugar igwa nin dakulang pitak, peligroso baklayon",
    ],
    ("Structural", "Medium"): [
        "An daan na barangay hall igwa nin mga pitak na sa lanob, kaipuhan suhayan",
        "An tulay sa samuyang barangay hababa na asin tibaad dai na matibay",
        "Dakul na pitak an lanob kan samuyang eskwelahan, tibaad peligroso",
    ],
    ("Structural", "Low"): [
        "An bakod kan parke digdi may sira na, dapat ayuson",
        "An pinto kan sityo hall sira na, masakit buksan",
        "May pitak sa plasa kan barangay, sadit sana man pero gusto ko sanang i-report",
    ],
    ("Security", "High"): [
        "May nagbabaril sa samuyang lugar, tako na an mga residente",
        "Naheling ko an sarong tawong may hawak na lading, nagbabanta sa mga tawo",
        "May nangagaw nin bag sa samuyang lugar, dakul na beses na ining nangyari",
        "May nag-iiriwal-wal asin naggagamit nin armas sa palengke, kaipuhan tulos nin pulis",
    ],
    ("Security", "Medium"): [
        "Dakul na adik an naheheling sa samuyang lugar kada banggi, kaipuhan aksyon",
        "May grupong nangongolekta nin lagay sa mga negosyante sa palengke",
        "Dakul na beses nang may naghahabon nin gulay sa samuyang sityo",
    ],
    ("Security", "Low"): [
        "Maribok an mga kabataan sa kanto kada banggi, dai kami makaturog",
        "Gusto ko sanang i-report na may mga estranghero na naheheling sa samuyang lugar",
        "May nagtatambay sa atubangan kan samuyang harong kada banggi",
    ],
    ("Infrastructure", "High"): [
        "Natumba an dakulang parte kan tulay sa samuyang lugar, peligroso",
        "Nagaba an pangenot na kalsada, dai na madadaanan kan mga sasakyan",
        "Nagbuto an sewage system asin nagresulta nin polusyon sa mga harong",
        "Natumba an retaining wall kan kalsada sa bukid, naipit an mga sasakyan",
    ],
    ("Infrastructure", "Medium"): [
        "An kalsada sa samuyang sityo garo lubak-lubak na asin gaba an drainage",
        "An tulay igwa nin dakulang lungag sa butnga, peligroso sa mga aki",
        "Gaba an mga manhole cover sa samuyang lugar, peligroso sa nagdadalagan",
    ],
    ("Infrastructure", "Low"): [
        "An pinto kan barangay basketball court sira na, dai nasasara",
        "An mga bangko sa plasa sira na, kaipuhan nin bagong bangko",
        "Gusto ko sanang i-report na an drainage sa samuyang sityo puno nin basura",
    ],
    ("Food", "High"): [
        "Dakul na tawo an naghelang pagkatapos kumaon sa kantina kan barangay",
        "May food poisoning na naeksperyensya kan dakul na residente hali sa sarong tindahan",
        "An tubig na ininom kan mga aki igwa nin kakaibang kahamis, tibaad kontaminado",
    ],
    ("Food", "Medium"): [
        "May tindahan sa palengke na nagbabakal nin maraot na karne, kaipuhan susugon",
        "Dakul na residente an dai nakakakaon huli sa kadaihan nin pagkaon",
        "Kaipuhan nin food assistance an dakul na pamilya sa samuyang barangay",
    ],
    ("Food", "Low"): [
        "Gusto ko sanang i-report na may nagbabakal nin expired na pagkaon sa tindahan",
        "Kaipuhan nin feeding program para sa mga aking mayong maabot na pagkaon",
    ],
    ("Animal", "High"): [
        "May ayam na daing kagsadiri na nagkakagat nin mga tawo sa samuyang lugar, peligroso",
        "Kinagat kan ayam an sarong aki na yaon sa dalan, kaipuhan nin tabang medikal",
        "Naheling an dakulang halas sa laog kan harong kan kataed mi, kaipuhan nin rescue",
    ],
    ("Animal", "Medium"): [
        "Dakul na ayam na daing kagsadiri sa samuyang lugar, delikado sa mga aki",
        "May naaamoy na maraot hali sa gadan na hayop sa salog, kaipuhan halion",
        "Dakul na daga na naghahaluwas sa samuyang lugar puon kan pagbaha",
    ],
    ("Animal", "Low"): [
        "Gusto ko sanang i-report na dakul na ayam na daing kagsadiri sa samuyang purok",
        "An mga ayam sa samuyang lugar mayong bakuna, dapat ayuson",
    ],
}

# ─── FILLER PHRASES PER LANGUAGE (added for natural variation) ─────────────

tagalog_prefixes = [
    "", "", "",
    "Mahal na barangay tanggapan, ",
    "Nagtatanong po kung may aksyon na, ",
    "Pakiusap sana ay tulungan kami, ",
    "Gusto ko lang ireport na ",
    "Nag aalala po kami dahil ",
    "Alam ko po na marami kayong trabaho pero ",
    "Importante po ito, ",
]
tagalog_suffixes = [
    "", "", "",
    " kailangan ng agad na aksyon.",
    " sana ay tulungan ninyo kami.",
    " pakiusap.",
    " salamat po.",
    " maraming salamat po.",
    " umaasa po kaming maaksyunan ito.",
    " kailangan na talaga ng tulong.",
    " maaari ba kayong tumulong?",
    " ito ay nangyari ngayon.",
    " nangyari ito kanina pa.",
]

bikol_prefixes = [
    "", "", "",
    "Mahal na tanggapan kan barangay, ",
    "Naghahapot ako kun igwa nang aksyon, ",
    "Pakiusap tabangan kami, ",
    "Gusto ko sanang i-report na ",
    "Nag-aalala kami huli ta ",
    "Aram ko na dakul kamong trabaho pero ",
    "Importante ini, ",
]
bikol_suffixes = [
    "", "", "",
    " kaipuhan nin tulong ngunyan.",
    " tabangan niyo kami tabi.",
    " pakiusap.",
    " salamat.",
    " dakul na salamat.",
    " naglalaom kami na maaksyunan ini.",
    " kaipuhan na gayod nin tabang.",
    " puwede daw kamong tumabang?",
    " ini nangyari ngunyan.",
]

# ─── GENERATE ROWS ────────────────────────────────────────────────────────

# Tagalog gets the larger share (established, higher-confidence data);
# Bikol gets a meaningful but smaller share until native-speaker review
# expands/corrects it.
tagalog_category_targets = {
    "Flooding":        75,
    "Medical":         65,
    "Fire":            55,
    "Road Hazard":     50,
    "Utility":         45,
    "Landslide":       40,
    "Power Hazard":    35,
    "Structural":      35,
    "Security":        35,
    "Infrastructure":  30,
    "Food":            20,
    "Animal":          15,
}

bikol_category_targets = {
    "Flooding":        30,
    "Medical":         24,
    "Fire":            22,
    "Road Hazard":     18,
    "Utility":         16,
    "Landslide":       16,
    "Power Hazard":    14,
    "Structural":      14,
    "Security":        14,
    "Infrastructure":  12,
    "Food":             9,
    "Animal":           9,
}

severity_weights = {"High": 0.55, "Medium": 0.30, "Low": 0.15}


def generate_rows(data, category_targets, prefixes, suffixes, language):
    rows = []
    for category, target_count in category_targets.items():
        for _ in range(target_count):
            severity = random.choices(
                list(severity_weights.keys()),
                weights=list(severity_weights.values())
            )[0]

            key = (category, severity)
            if key not in data or not data[key]:
                for fallback in ["Medium", "High", "Low"]:
                    key = (category, fallback)
                    if key in data and data[key]:
                        severity = fallback
                        break

            base_texts = data[key]
            base = random.choice(base_texts)
            prefix = random.choice(prefixes)
            suffix = random.choice(suffixes)

            text = f"{prefix}{base}{suffix}".strip()

            rows.append({
                "report_text": text,
                "category": category,
                "severity": severity,
                "language": language,
            })
    return rows


rows = []
rows += generate_rows(tagalog_data, tagalog_category_targets, tagalog_prefixes, tagalog_suffixes, "tagalog")
rows += generate_rows(bikol_data, bikol_category_targets, bikol_prefixes, bikol_suffixes, "bikol")

df = pd.DataFrame(rows)
df = df.sample(frac=1, random_state=42).reset_index(drop=True)

OUTPUT_PATH = "data/reports.csv"
df.to_csv(OUTPUT_PATH, index=False)

print(f"Wrote {len(df)} rows to {OUTPUT_PATH}")
print("\nLanguage breakdown:")
print(df["language"].value_counts().to_dict())
print("\nSeverity breakdown:")
print(df["severity"].value_counts().to_dict())
print("\nSeverity breakdown by language:")
print(df.groupby(["language", "severity"]).size().to_dict())
print("\nCategory breakdown:")
print(df["category"].value_counts().to_dict())
