// lib/helpers/turkey_cities_helper.dart
// Türkiye'nin tüm 81 ili ve ilçeleri

class TurkeyCitiesHelper {
  static const Map<String, List<String>> provincesAndDistricts = {
    'Adana': [
      'Aladağ', 'Ceyhan', 'Çukurova', 'Feke', 'İmamoğlu', 'Karaisalı', 'Karataş',
      'Kozan', 'Pozantı', 'Saimbeyli', 'Sarıçam', 'Seyhan', 'Tufanbeyli', 'Yumurtalık', 'Yüreğir'
    ],
    'Adıyaman': [
      'Besni', 'Çelikhan', 'Gerger', 'Gölbaşı', 'Kahta', 'Merkez', 'Samsat',
      'Sincik', 'Tut'
    ],
    'Afyonkarahisar': [
      'Başmakçı', 'Bayat', 'Bolvadin', 'Çay', 'Çobanlar', 'Dazkırı', 'Dinar',
      'Emirdağ', 'Evciler', 'Hocalar', 'İhsaniye', 'İscehisar', 'Kızılören',
      'Merkez', 'Sandıklı', 'Sinanpaşa', 'Sultandağı', 'Şuhut'
    ],
    'Ağrı': [
      'Diyadin', 'Doğubayazıt', 'Eleşkirt', 'Hamur', 'Merkez', 'Patnos', 'Taşlıçay', 'Tutak'
    ],
    'Aksaray': [
      'Ağaçören', 'Eskil', 'Gülağaç', 'Güzelyurt', 'Merkez', 'Ortaköy', 'Sarıyahşi'
    ],
    'Amasya': [
      'Göynücek', 'Gümüşhacıköy', 'Hamamözü', 'Merkez', 'Merzifon', 'Suluova', 'Taşova'
    ],
    'Ankara': [
      'Akyurt', 'Altındağ', 'Ayaş', 'Bala', 'Beypazarı', 'Çamlıdere', 'Çankaya',
      'Çubuk', 'Elmadağ', 'Etimesgut', 'Evren', 'Gölbaşı', 'Güdül', 'Haymana',
      'Kalecik', 'Kazan', 'Keçiören', 'Kızılcahamam', 'Mamak', 'Nallıhan',
      'Polatlı', 'Pursaklar', 'Sincan', 'Şereflikoçhisar', 'Yenimahalle'
    ],
    'Antalya': [
      'Aksu', 'Alanya', 'Demre', 'Döşemealtı', 'Elmalı', 'Finike', 'Gazipaşa',
      'Gündoğmuş', 'İbradı', 'Kaş', 'Kemer', 'Kepez', 'Konyaaltı', 'Korkuteli',
      'Kumluca', 'Manavgat', 'Muratpaşa', 'Serik'
    ],
    'Ardahan': [
      'Çıldır', 'Damal', 'Göle', 'Hanak', 'Merkez', 'Posof'
    ],
    'Artvin': [
      'Ardanuç', 'Arhavi', 'Borçka', 'Hopa', 'Merkez', 'Murgul', 'Şavşat', 'Yusufeli'
    ],
    'Aydın': [
      'Bozdoğan', 'Buharkent', 'Çine', 'Didim', 'Efeler', 'Germencik', 'İncirliova',
      'Karacasu', 'Karpuzlu', 'Koçarlı', 'Köşk', 'Kuşadası', 'Kuyucak', 'Nazilli',
      'Söke', 'Sultanhisar', 'Yenipazar'
    ],
    'Balıkesir': [
      'Altıeylül', 'Ayvalık', 'Balya', 'Bandırma', 'Bigadiç', 'Burhaniye', 'Dursunbey',
      'Edremit', 'Erdek', 'Gömeç', 'Gönen', 'Havran', 'İvrindi', 'Karesi', 'Kepsut',
      'Manyas', 'Marmara', 'Savaştepe', 'Sındırgı', 'Susurluk'
    ],
    'Bartın': [
      'Amasra', 'Kurucaşile', 'Merkez', 'Ulus'
    ],
    'Batman': [
      'Beşiri', 'Gercüş', 'Hasankeyf', 'Kozluk', 'Merkez', 'Sason'
    ],
    'Bayburt': [
      'Aydıntepe', 'Demirözü', 'Merkez'
    ],
    'Bilecik': [
      'Bozüyük', 'Gölpazarı', 'İnhisar', 'Merkez', 'Osmaneli', 'Pazaryeri', 'Söğüt', 'Yenipazar'
    ],
    'Bingöl': [
      'Adaklı', 'Genç', 'Karlıova', 'Kiğı', 'Merkez', 'Solhan', 'Yayladere', 'Yedisu'
    ],
    'Bitlis': [
      'Adilcevaz', 'Ahlat', 'Güroymak', 'Hizan', 'Merkez', 'Mutki', 'Tatvan'
    ],
    'Bolu': [
      'Dörtdivan', 'Gerede', 'Göynük', 'Kıbrıscık', 'Mengen', 'Merkez', 'Mudurnu',
      'Seben', 'Yeniçağa'
    ],
    'Burdur': [
      'Ağlasun', 'Altınyayla', 'Bucak', 'Çavdır', 'Çeltikçi', 'Gölhisar', 'Karamanlı',
      'Kemer', 'Merkez', 'Tefenni', 'Yeşilova'
    ],
    'Bursa': [
      'Büyükorhan', 'Gemlik', 'Gürsu', 'Harmancık', 'İnegöl', 'İznik', 'Karacabey',
      'Keles', 'Kestel', 'Mudanya', 'Mustafakemalpaşa', 'Nilüfer', 'Orhaneli',
      'Orhangazi', 'Osmangazi', 'Yenişehir', 'Yıldırım'
    ],
    'Çanakkale': [
      'Ayvacık', 'Bayramiç', 'Biga', 'Bozcaada', 'Çan', 'Eceabat', 'Ezine',
      'Gelibolu', 'Gökçeada', 'Lapseki', 'Merkez', 'Yenice'
    ],
    'Çankırı': [
      'Atkaracalar', 'Bayramören', 'Çerkeş', 'Eldivan', 'Ilgaz', 'Kızılırmak',
      'Korgun', 'Kurşunlu', 'Merkez', 'Orta', 'Şabanözü', 'Yapraklı'
    ],
    'Çorum': [
      'Alaca', 'Bayat', 'Boğazkale', 'Dodurga', 'İskilip', 'Kargı', 'Laçin',
      'Mecitözü', 'Merkez', 'Oğuzlar', 'Ortaköy', 'Osmancık', 'Sungurlu', 'Uğurludağ'
    ],
    'Denizli': [
      'Acıpayam', 'Babadağ', 'Baklan', 'Bekilli', 'Beyağaç', 'Bozkurt', 'Buldan',
      'Çal', 'Çameli', 'Çardak', 'Çivril', 'Güney', 'Honaz', 'Kale', 'Merkezefendi',
      'Pamukkale', 'Sarayköy', 'Serinhisar', 'Tavas'
    ],
    'Diyarbakır': [
      'Bağlar', 'Bismil', 'Çermik', 'Çınar', 'Çüngüş', 'Dicle', 'Eğil', 'Ergani',
      'Hani', 'Hazro', 'Kayapınar', 'Kocaköy', 'Kulp', 'Lice', 'Silvan', 'Sur', 'Yenişehir'
    ],
    'Düzce': [
      'Akçakoca', 'Cumayeri', 'Çilimli', 'Gölyaka', 'Gümüşova', 'Kaynaşlı', 'Merkez', 'Yığılca'
    ],
    'Edirne': [
      'Enez', 'Havsa', 'İpsala', 'Keşan', 'Lalapaşa', 'Meriç', 'Merkez', 'Süloğlu', 'Uzunköprü'
    ],
    'Elazığ': [
      'Ağın', 'Alacakaya', 'Arıcak', 'Baskil', 'Karakoçan', 'Keban', 'Kovancılar',
      'Maden', 'Merkez', 'Palu', 'Sivrice'
    ],
    'Erzincan': [
      'Çayırlı', 'İliç', 'Kemah', 'Kemaliye', 'Merkez', 'Otlukbeli', 'Refahiye',
      'Tercan', 'Üzümlü'
    ],
    'Erzurum': [
      'Aşkale', 'Aziziye', 'Çat', 'Hınıs', 'Horasan', 'İspir', 'Karaçoban',
      'Karayazı', 'Köprüköy', 'Narman', 'Oltu', 'Olur', 'Palandöken', 'Pasinler',
      'Pazaryolu', 'Şenkaya', 'Tekman', 'Tortum', 'Uzundere', 'Yakutiye'
    ],
    'Eskişehir': [
      'Alpu', 'Beylikova', 'Çifteler', 'Günyüzü', 'Han', 'İnönü', 'Mahmudiye',
      'Mihalgazi', 'Mihalıççık', 'Odunpazarı', 'Sarıcakaya', 'Seyitgazi', 'Sivrihisar', 'Tepebaşı'
    ],
    'Gaziantep': [
      'Araban', 'İslahiye', 'Karkamış', 'Nizip', 'Nurdağı', 'Oğuzeli', 'Şahinbey',
      'Şehitkamil', 'Yavuzeli'
    ],
    'Giresun': [
      'Alucra', 'Bulancak', 'Çamoluk', 'Çanakçı', 'Dereli', 'Doğankent', 'Espiye',
      'Eynesil', 'Görele', 'Güce', 'Keşap', 'Merkez', 'Piraziz', 'Şebinkarahisar',
      'Tirebolu', 'Yağlıdere'
    ],
    'Gümüşhane': [
      'Kelkit', 'Köse', 'Kürtün', 'Merkez', 'Şiran', 'Torul'
    ],
    'Hakkari': [
      'Çukurca', 'Derecik', 'Merkez', 'Şemdinli', 'Yüksekova'
    ],
    'Hatay': [
      'Altınözü', 'Antakya', 'Arsuz', 'Belen', 'Defne', 'Dörtyol', 'Erzin',
      'Hassa', 'İskenderun', 'Kırıkhan', 'Kumlu', 'Payas', 'Reyhanlı', 'Samandağ', 'Yayladağı'
    ],
    'Iğdır': [
      'Aralık', 'Karakoyunlu', 'Merkez', 'Tuzluca'
    ],
    'Isparta': [
      'Aksu', 'Atabey', 'Eğirdir', 'Gelendost', 'Gönen', 'Keçiborlu', 'Merkez',
      'Senirkent', 'Sütçüler', 'Şarkikaraağaç', 'Uluborlu', 'Yalvaç', 'Yenişarbademli'
    ],
    'İstanbul': [
      'Adalar', 'Arnavutköy', 'Ataşehir', 'Avcılar', 'Bağcılar', 'Bahçelievler',
      'Bakırköy', 'Başakşehir', 'Bayrampaşa', 'Beşiktaş', 'Beykoz', 'Beylikdüzü',
      'Beyoğlu', 'Büyükçekmece', 'Çatalca', 'Çekmeköy', 'Esenler', 'Esenyurt',
      'Eyüpsultan', 'Fatih', 'Gaziosmanpaşa', 'Güngören', 'Kadıköy', 'Kağıthane',
      'Kartal', 'Küçükçekmece', 'Maltepe', 'Pendik', 'Sancaktepe', 'Sarıyer',
      'Silivri', 'Sultanbeyli', 'Sultangazi', 'Şile', 'Şişli', 'Tuzla', 'Ümraniye',
      'Üsküdar', 'Zeytinburnu'
    ],
    'İzmir': [
      'Aliağa', 'Balçova', 'Bayındır', 'Bayraklı', 'Bergama', 'Beydağ', 'Bornova',
      'Buca', 'Çeşme', 'Çiğli', 'Dikili', 'Foça', 'Gaziemir', 'Güzelbahçe',
      'Karabağlar', 'Karaburun', 'Karşıyaka', 'Kemalpaşa', 'Kınık', 'Kiraz',
      'Konak', 'Menderes', 'Menemen', 'Narlıdere', 'Ödemiş', 'Seferihisar',
      'Selçuk', 'Tire', 'Torbalı', 'Urla'
    ],
    'Kahramanmaraş': [
      'Afşin', 'Andırın', 'Çağlayancerit', 'Dulkadiroğlu', 'Ekinözü', 'Elbistan',
      'Göksun', 'Nurhak', 'Onikişubat', 'Pazarcık', 'Türkoğlu'
    ],
    'Karabük': [
      'Eflani', 'Eskipazar', 'Merkez', 'Ovacık', 'Safranbolu', 'Yenice'
    ],
    'Karaman': [
      'Ayrancı', 'Başyayla', 'Ermenek', 'Kazımkarabekir', 'Merkez', 'Sarıveliler'
    ],
    'Kars': [
      'Akyaka', 'Arpaçay', 'Digor', 'Kağızman', 'Merkez', 'Sarıkamış', 'Selim', 'Susuz'
    ],
    'Kastamonu': [
      'Abana', 'Ağlı', 'Araç', 'Azdavay', 'Bozkurt', 'Cide', 'Çatalzeytin',
      'Daday', 'Devrekani', 'Doğanyurt', 'Hanönü', 'İhsangazi', 'İnebolu',
      'Küre', 'Merkez', 'Pınarbaşı', 'Seydiler', 'Şenpazar', 'Taşköprü', 'Tosya'
    ],
    'Kayseri': [
      'Akkışla', 'Bünyan', 'Develi', 'Felahiye', 'Hacılar', 'İncesu', 'Kocasinan',
      'Melikgazi', 'Özvatan', 'Pınarbaşı', 'Sarıoğlan', 'Sarız', 'Talas', 'Tomarza', 'Yahyalı', 'Yeşilhisar'
    ],
    'Kırıkkale': [
      'Bahşılı', 'Balışeyh', 'Çelebi', 'Delice', 'Karakeçili', 'Keskin', 'Merkez', 'Sulakyurt', 'Yahşihan'
    ],
    'Kırklareli': [
      'Babaeski', 'Demirköy', 'Kofçaz', 'Lüleburgaz', 'Merkez', 'Pehlivanköy', 'Pınarhisar', 'Vize'
    ],
    'Kırşehir': [
      'Akçakent', 'Akpınar', 'Boztepe', 'Çiçekdağı', 'Kaman', 'Merkez', 'Mucur'
    ],
    'Kilis': [
      'Elbeyli', 'Merkez', 'Musabeyli', 'Polateli'
    ],
    'Kocaeli': [
      'Başiskele', 'Çayırova', 'Darıca', 'Derince', 'Dilovası', 'Gebze', 'Gölcük',
      'İzmit', 'Kandıra', 'Karamürsel', 'Körfez', 'Yalova'
    ],
    'Konya': [
      'Ahırlı', 'Akören', 'Akşehir', 'Altınekin', 'Beyşehir', 'Bozkır', 'Cihanbeyli',
      'Çeltik', 'Çumra', 'Derbent', 'Derebucak', 'Doğanhisar', 'Emirgazi', 'Ereğli',
      'Güneysınır', 'Hadim', 'Halkapınar', 'Hüyük', 'Ilgın', 'Kadınhanı', 'Karapınar',
      'Karatay', 'Kulu', 'Meram', 'Sarayönü', 'Selçuklu', 'Seydişehir', 'Taşkent',
      'Tuzlukçu', 'Yalıhüyük', 'Yunak'
    ],
    'Kütahya': [
      'Altıntaş', 'Aslanapa', 'Çavdarhisar', 'Domaniç', 'Dumlupınar', 'Emet',
      'Gediz', 'Hisarcık', 'Merkez', 'Pazarlar', 'Simav', 'Şaphane', 'Tavşanlı'
    ],
    'Malatya': [
      'Akçadağ', 'Arapgir', 'Arguvan', 'Battalgazi', 'Darende', 'Doğanşehir',
      'Doğanyol', 'Hekimhan', 'Kale', 'Kuluncak', 'Pütürge', 'Yazıhan', 'Yeşilyurt'
    ],
    'Manisa': [
      'Ahmetli', 'Akhisar', 'Alaşehir', 'Demirci', 'Gölmarmara', 'Gördes',
      'Kırkağaç', 'Köprübaşı', 'Kula', 'Salihli', 'Sarıgöl', 'Saruhanlı',
      'Selendi', 'Soma', 'Şehzadeler', 'Turgutlu', 'Yunusemre'
    ],
    'Mardin': [
      'Artuklu', 'Dargeçit', 'Derik', 'Kızıltepe', 'Mazıdağı', 'Midyat',
      'Nusaybin', 'Ömerli', 'Savur', 'Yeşilli'
    ],
    'Mersin': [
      'Akdeniz', 'Anamur', 'Aydıncık', 'Bozyazı', 'Çamlıyayla', 'Erdemli',
      'Gülnar', 'Mezitli', 'Mut', 'Silifke', 'Tarsus', 'Toroslar', 'Yenişehir'
    ],
    'Muğla': [
      'Bodrum', 'Dalaman', 'Datça', 'Fethiye', 'Kavaklıdere', 'Köyceğiz',
      'Marmaris', 'Menteşe', 'Milas', 'Ortaca', 'Seydikemer', 'Ula', 'Yatağan'
    ],
    'Muş': [
      'Bulanık', 'Hasköy', 'Korkut', 'Malazgirt', 'Merkez', 'Varto'
    ],
    'Nevşehir': [
      'Acıgöl', 'Avanos', 'Derinkuyu', 'Gülşehir', 'Hacıbektaş', 'Kozaklı',
      'Merkez', 'Ürgüp'
    ],
    'Niğde': [
      'Altunhisar', 'Bor', 'Çamardı', 'Çiftlik', 'Merkez', 'Ulukışla'
    ],
    'Ordu': [
      'Akkuş', 'Altınordu', 'Aybastı', 'Çamaş', 'Çatalpınar', 'Çaybaşı',
      'Fatsa', 'Gölköy', 'Gülyalı', 'Gürgentepe', 'İkizce', 'Kabadüz',
      'Kabataş', 'Korgan', 'Kumru', 'Mesudiye', 'Perşembe', 'Ulubey', 'Ünye'
    ],
    'Osmaniye': [
      'Bahçe', 'Düziçi', 'Hasanbeyli', 'Kadirli', 'Merkez', 'Sumbas', 'Toprakkale'
    ],
    'Rize': [
      'Ardeşen', 'Çamlıhemşin', 'Çayeli', 'Derepazarı', 'Fındıklı', 'Güneysu',
      'Hemşin', 'İkizdere', 'İyidere', 'Kalkandere', 'Merkez', 'Pazar'
    ],
    'Sakarya': [
      'Adapazarı', 'Akyazı', 'Arifiye', 'Erenler', 'Ferizli', 'Geyve',
      'Hendek', 'Karapürçek', 'Karasu', 'Kaynarca', 'Kocaali', 'Pamukova',
      'Sapanca', 'Serdivan', 'Söğütlü', 'Taraklı'
    ],
    'Samsun': [
      'Alaçam', 'Asarcık', 'Atakum', 'Ayvacık', 'Bafra', 'Canik', 'Çarşamba',
      'Havza', 'İlkadım', 'Kavak', 'Ladik', 'Ondokuzmayıs', 'Salıpazarı',
      'Tekkeköy', 'Terme', 'Vezirköprü', 'Yakakent'
    ],
    'Siirt': [
      'Baykan', 'Eruh', 'Kurtalan', 'Merkez', 'Pervari', 'Şirvan', 'Tillo'
    ],
    'Sinop': [
      'Ayancık', 'Boyabat', 'Dikmen', 'Durağan', 'Erfelek', 'Gerze',
      'Merkez', 'Saraydüzü', 'Türkeli'
    ],
    'Sivas': [
      'Akıncılar', 'Altınyayla', 'Divriği', 'Doğanşar', 'Gemerek', 'Gölova',
      'Gürün', 'Hafik', 'İmranlı', 'Kangal', 'Koyulhisar', 'Merkez',
      'Suşehri', 'Şarkışla', 'Ulaş', 'Yıldızeli', 'Zara'
    ],
    'Şanlıurfa': [
      'Akçakale', 'Birecik', 'Bozova', 'Ceylanpınar', 'Eyyübiye', 'Halfeti',
      'Haliliye', 'Harran', 'Hilvan', 'Karaköprü', 'Siverek', 'Suruç', 'Viranşehir'
    ],
    'Şırnak': [
      'Beytüşşebap', 'Cizre', 'Güçlükonak', 'İdil', 'Merkez', 'Silopi', 'Uludere'
    ],
    'Tekirdağ': [
      'Çerkezköy', 'Çorlu', 'Ergene', 'Hayrabolu', 'Kapaklı', 'Malkara',
      'Marmaraereğlisi', 'Muratlı', 'Saray', 'Süleymanpaşa', 'Şarköy'
    ],
    'Tokat': [
      'Almus', 'Artova', 'Başçiftlik', 'Erbaa', 'Merkez', 'Niksar',
      'Pazar', 'Reşadiye', 'Sulusaray', 'Turhal', 'Yeşilyurt', 'Zile'
    ],
    'Trabzon': [
      'Akçaabat', 'Araklı', 'Arsin', 'Beşikdüzü', 'Çaykara', 'Çarşıbaşı',
      'Dernekpazarı', 'Düzköy', 'Hayrat', 'Köprübaşı', 'Maçka', 'Of',
      'Ortahisar', 'Sürmene', 'Şalpazarı', 'Tonya', 'Vakfıkebir', 'Yomra'
    ],
    'Tunceli': [
      'Çemişgezek', 'Hozat', 'Mazgirt', 'Merkez', 'Nazımiye', 'Ovacık', 'Pertek', 'Pülümür'
    ],
    'Uşak': [
      'Banaz', 'Eşme', 'Karahallı', 'Merkez', 'Sivaslı', 'Ulubey'
    ],
    'Van': [
      'Bahçesaray', 'Başkale', 'Çaldıran', 'Çatak', 'Edremit', 'Erciş',
      'Gevaş', 'Gürpınar', 'İpekyolu', 'Muradiye', 'Özalp', 'Saray', 'Tuşba'
    ],
    'Yalova': [
      'Altınova', 'Armutlu', 'Çınarcık', 'Çiftlikköy', 'Merkez', 'Termal'
    ],
    'Yozgat': [
      'Akdağmadeni', 'Aydıncık', 'Boğazlıyan', 'Çandır', 'Çayıralan', 'Çekerek',
      'Kadışehri', 'Merkez', 'Saraykent', 'Sarıkaya', 'Şefaatli', 'Sorgun', 'Yenifakılı', 'Yerköy'
    ],
    'Zonguldak': [
      'Alaplı', 'Çaycuma', 'Devrek', 'Gökçebey', 'Kilimli', 'Kozlu', 'Merkez'
    ],
  };

  // Getter methods for easy access
  static List<String> get allProvinces {
    return provincesAndDistricts.keys.toList()..sort();
  }

  static List<String> get allProvincesWithAll {
    return ['Tüm İller'] + allProvinces;
  }

  static List<String> getDistricts(String province) {
    return provincesAndDistricts[province] ?? [];
  }

  static List<String> getDistrictsWithAll(String province) {
    if (province == 'Tüm İller' || !provincesAndDistricts.containsKey(province)) {
      return ['Tüm İlçeler'];
    }
    return ['Tüm İlçeler'] + getDistricts(province);
  }

  // Search methods
  static List<String> searchProvinces(String query) {
    if (query.isEmpty) return allProvinces;

    return allProvinces
        .where((province) =>
        province.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  static List<String> searchDistricts(String province, String query) {
    final districts = getDistricts(province);
    if (query.isEmpty) return districts;

    return districts
        .where((district) =>
        district.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  // Validation methods
  static bool isValidProvince(String province) {
    return provincesAndDistricts.containsKey(province);
  }

  static bool isValidDistrict(String province, String district) {
    return provincesAndDistricts[province]?.contains(district) ?? false;
  }

  // Get total counts
  static int get totalProvinces => provincesAndDistricts.length;

  static int get totalDistricts {
    return provincesAndDistricts.values
        .fold(0, (sum, districts) => sum + districts.length);
  }

  static int getDistrictCount(String province) {
    return provincesAndDistricts[province]?.length ?? 0;
  }
}