import Foundation

/// 📖 نصوص للقراءة — بالعربية. يقرأ الطفل المقطع ثم يجيب عن أسئلة عنه.
/// مأخوذة عن المجموعة العبرية، وكلّ إجابة ما زالت موجودة في النصّ نفسه.
extension ArabicContent {
    static let readingPassages: [ReadingPassage] = [
        ReadingPassage(
            id: "cat_roof", tier: .easy,
            text: "عند ليان قطّة اسمها لونا. تحبّ لونا أن تنام على السطح الدافئ.",
            questions: [
                BankQuestion(prompt: "ما اسم القطّة؟", correctAnswer: "لونا", distractors: ["ليان", "الشمس", "القمر"], tier: .easy, grades: 1...2),
                BankQuestion(prompt: "أين تحبّ لونا أن تنام؟", correctAnswer: "على السطح", distractors: ["في السرير", "في الحديقة", "على الأريكة"], tier: .easy, grades: 1...2),
            ]),
        ReadingPassage(
            id: "red_ball", tier: .easy,
            text: "حصل كرم على كرة حمراء في عيد ميلاده. لعب بها في الساحة مع أخيه الصغير.",
            questions: [
                BankQuestion(prompt: "ما لون الكرة؟", correctAnswer: "أحمر", distractors: ["أزرق", "أخضر", "أصفر"], tier: .easy, grades: 1...2),
                BankQuestion(prompt: "مع من لعب كرم؟", correctAnswer: "مع أخيه الصغير", distractors: ["مع أبيه", "مع صديق من الروضة", "وحده"], tier: .easy, grades: 1...2),
                BankQuestion(prompt: "لماذا حصل كرم على الكرة؟", correctAnswer: "في عيد ميلاده", distractors: ["لأنّه فاز في مباراة", "في عيد الفطر", "بلا سبب"], tier: .easy, grades: 1...2),
            ]),
        ReadingPassage(
            id: "rain_boots", tier: .easy,
            text: "نزل مطر قويّ في الخارج. لبست مريم جزمة ورديّة وقفزت في برك الماء.",
            questions: [
                BankQuestion(prompt: "ماذا نزل في الخارج؟", correctAnswer: "مطر", distractors: ["ثلج", "بَرَد", "أوراق"], tier: .easy, grades: 1...2),
                BankQuestion(prompt: "ماذا لبست مريم؟", correctAnswer: "جزمة ورديّة", distractors: ["صندل", "حذاء رياضة", "جزمة زرقاء"], tier: .easy, grades: 1...2),
            ]),
        ReadingPassage(
            id: "dog_bone", tier: .easy,
            text: "حفر الكلب ركس حفرة في الحديقة. وخبّأ فيها عظمة كبيرة للغد.",
            questions: [
                BankQuestion(prompt: "ماذا فعل ركس في الحديقة؟", correctAnswer: "حفر حفرة", distractors: ["قطف أزهارًا", "طارد قطّة", "نام في الشمس"], tier: .easy, grades: 1...2),
                BankQuestion(prompt: "ماذا خبّأ ركس في الحفرة؟", correctAnswer: "عظمة كبيرة", distractors: ["كرة", "حذاء", "طعام قطط"], tier: .easy, grades: 1...2),
            ]),
        ReadingPassage(
            id: "morning_sun", tier: .easy,
            text: "في الصباح أشرقت الشمس. أعدّت الأمّ لآدم حليبًا بالكاكاو وخبزًا بالمربّى.",
            questions: [
                BankQuestion(prompt: "ماذا أعدّت الأمّ لآدم؟", correctAnswer: "حليبًا بالكاكاو وخبزًا بالمربّى", distractors: ["حساءً ساخنًا", "بيتزا", "عصيدة بالعسل"], tier: .easy, grades: 1...2),
                BankQuestion(prompt: "متى حدث ذلك؟", correctAnswer: "في الصباح", distractors: ["في الليل", "عند الظهر", "في المساء"], tier: .easy, grades: 1...2),
            ]),
        ReadingPassage(
            id: "library_visit", tier: .easy,
            text: "ذهب جاد مع جدّته إلى المكتبة. واختار كتابًا عن الديناصورات.",
            questions: [
                BankQuestion(prompt: "إلى أين ذهب جاد؟", correctAnswer: "إلى المكتبة", distractors: ["إلى الروضة", "إلى الدكّان", "إلى المسبح"], tier: .easy, grades: 1...2),
                BankQuestion(prompt: "عن ماذا يتحدّث الكتاب الذي اختاره جاد؟", correctAnswer: "عن الديناصورات", distractors: ["عن الفضاء", "عن القراصنة", "عن الكلاب"], tier: .easy, grades: 1...2),
            ]),
        ReadingPassage(
            id: "picnic_ants", tier: .medium,
            text: "يوم الجمعة ذهبت عائلة نصّار في نزهة إلى الحديقة العامّة. فرشت الأمّ بطّانيّة كبيرة تحت شجرة، وأخرج الأب السندويشات والبطّيخ. وفجأة وصل طابور من النمل مباشرة إلى الكعكة. ضحك الجميع ونقلوا البطّانيّة إلى مكان آخر.",
            questions: [
                BankQuestion(prompt: "متى ذهبت العائلة في النزهة؟", correctAnswer: "يوم الجمعة", distractors: ["يوم السبت", "يوم الأحد", "في العطلة الصيفيّة"], tier: .medium, grades: 2...4),
                BankQuestion(prompt: "إلى أين وصل النمل؟", correctAnswer: "إلى الكعكة", distractors: ["إلى البطّيخ", "إلى السندويشات", "إلى الشجرة"], tier: .medium, grades: 2...4),
                BankQuestion(prompt: "ماذا فعلت العائلة في النهاية؟", correctAnswer: "نقلت البطّانيّة إلى مكان آخر", distractors: ["عادت إلى البيت", "رمت الكعكة", "طاردت النمل"], tier: .medium, grades: 2...4),
            ]),
        ReadingPassage(
            id: "lost_tooth", tier: .medium,
            text: "تحرّكت سنّ نور منذ أسبوع كامل. وفي وجبة المساء، بينما كانت تقضم تفّاحة، وقعت السنّ! وضعت نور السنّ تحت الوسادة. وفي الصباح وجدت هناك قطعة نقود لامعة.",
            questions: [
                BankQuestion(prompt: "كم من الوقت تحرّكت السنّ؟", correctAnswer: "أسبوعًا", distractors: ["يومًا واحدًا", "شهرًا", "ساعة"], tier: .medium, grades: 2...4),
                BankQuestion(prompt: "متى وقعت السنّ؟", correctAnswer: "حين قضمت نور تفّاحة", distractors: ["حين نظّفت نور أسنانها", "أثناء النوم", "أثناء اللعب في الساحة"], tier: .medium, grades: 2...4),
                BankQuestion(prompt: "ماذا وجدت نور تحت الوسادة؟", correctAnswer: "قطعة نقود لامعة", distractors: ["سنًّا جديدة", "حلوى", "رسالة"], tier: .medium, grades: 2...4),
            ]),
        ReadingPassage(
            id: "robot_project", tier: .medium,
            text: "في درس العلوم بنى رامي وسارة روبوتًا صغيرًا من علب الكرتون. كان الروبوت يعرف أن يحرّك يدًا واحدة وأن يضيء مصباحًا أحمر في أنفه. وفي معرض المدرسة فاز الروبوت بالمركز الأوّل، وعلّقت المعلّمة صورته على لوح الصفّ.",
            questions: [
                BankQuestion(prompt: "ممّ بنى رامي وسارة الروبوت؟", correctAnswer: "من علب الكرتون", distractors: ["من مكعّبات الليغو", "من المعجون", "من الحديد"], tier: .medium, grades: 2...4),
                BankQuestion(prompt: "ماذا كان الروبوت يعرف أن يضيء؟", correctAnswer: "مصباحًا أحمر في أنفه", distractors: ["كشّافًا في يده", "شاشة صغيرة", "عينين خضراوين"], tier: .medium, grades: 2...4),
                BankQuestion(prompt: "بماذا فاز الروبوت في المعرض؟", correctAnswer: "بالمركز الأوّل", distractors: ["بالمركز الثاني", "بميداليّة فضّيّة", "بجائزة الجمهور"], tier: .medium, grades: 2...4),
            ]),
        ReadingPassage(
            id: "grandpa_garden", tier: .medium,
            text: "في كلّ يوم ثلاثاء يساعد جاد جدّه في الحديقة. هذا الأسبوع زرعا بندورة وخيارًا. علّم الجدّ جادًا أنّ النباتات تحتاج إلى شمس وماء وصبر كثير. ووعد جاد أن يسقي الحديقة أيضًا في الأيّام التي يستريح فيها الجدّ.",
            questions: [
                BankQuestion(prompt: "في أيّ يوم يساعد جاد جدّه؟", correctAnswer: "يوم الثلاثاء", distractors: ["يوم الجمعة", "يوم السبت", "كلّ يوم"], tier: .medium, grades: 2...4),
                BankQuestion(prompt: "ماذا زرعا هذا الأسبوع؟", correctAnswer: "بندورة وخيارًا", distractors: ["أزهارًا", "تفّاحًا وإجّاصًا", "فراولة"], tier: .medium, grades: 2...4),
                BankQuestion(prompt: "بحسب الجدّ، ماذا تحتاج النباتات؟", correctAnswer: "شمسًا وماءً وصبرًا", distractors: ["ماءً فقط", "ظلامًا وبردًا", "موسيقى هادئة"], tier: .medium, grades: 2...4),
            ]),
        ReadingPassage(
            id: "beach_shell", tier: .medium,
            text: "في العطلة سافرت سارة مع والديها إلى البحر. جمعت الأصداف في دلو أزرق وبنت قصرًا من الرمل ببرجين. وصلت موجة كبيرة ومحت القصر، لكنّ سارة لم تحزن. قالت: «غدًا نبني قصرًا أكبر!»",
            questions: [
                BankQuestion(prompt: "في ماذا جمعت سارة الأصداف؟", correctAnswer: "في دلو أزرق", distractors: ["في كيس", "في قبّعة", "في دلو أحمر"], tier: .medium, grades: 2...4),
                BankQuestion(prompt: "ماذا حدث لقصر الرمل؟", correctAnswer: "محته موجة", distractors: ["داس عليه ولد", "بقي حتّى المساء", "بعثرته الريح"], tier: .medium, grades: 2...4),
                BankQuestion(prompt: "كيف شعرت سارة في النهاية؟", correctAnswer: "لم تحزن، وخطّطت لتبني من جديد", distractors: ["بكت طوال الطريق", "غضبت على البحر", "خافت من الأمواج"], tier: .medium, grades: 2...4),
            ]),
        ReadingPassage(
            id: "class_pet", tier: .medium,
            text: "في الصفّ الثاني «ب» هامستر اسمه فستق. كلّ أسبوع يأخذه تلميذ آخر إلى البيت في عطلة نهاية الأسبوع. هذا الأسبوع كان دور مريم، فأعدّت لفستق ملعبًا من لفائف الورق. استمتع فستق كثيرًا حتّى نام داخل إحدى اللفائف.",
            questions: [
                BankQuestion(prompt: "أيّ حيوان في الصفّ؟", correctAnswer: "هامستر", distractors: ["أرنب", "ببغاء", "سمكة ذهبيّة"], tier: .medium, grades: 2...4),
                BankQuestion(prompt: "ماذا أعدّت مريم لفستق؟", correctAnswer: "ملعبًا من لفائف الورق", distractors: ["كعكة صغيرة", "بيتًا من الليغو", "كنزة صوف"], tier: .medium, grades: 2...4),
                BankQuestion(prompt: "أين نام فستق؟", correctAnswer: "داخل لفافة ورق", distractors: ["في القفص", "على الأريكة", "في جيب مريم"], tier: .medium, grades: 2...4),
            ]),
        ReadingPassage(
            id: "night_hike", tier: .hard,
            text: "في مساء السبت خرجت عائلة حدّاد في رحلة ليليّة إلى الغابة. وزّع الأب على الجميع كشّافات، وشرح أنّ حيوانات كثيرة تستيقظ في الليل، تمامًا حين نذهب نحن إلى النوم. وفجأة سمعوا صوت نباح غريب بين الأشجار. تجمّد الأولاد في أماكنهم، لكنّ الأب ابتسم وهمس: «إنّه مجرّد ابن آوى — هو يخاف منّا أكثر ممّا نخاف نحن منه.» وفي طريق العودة عدّ الأولاد سبعة أزواج من العيون اللامعة في العتمة.",
            questions: [
                BankQuestion(prompt: "متى خرجت العائلة في الرحلة؟", correctAnswer: "في مساء السبت", distractors: ["في صباح الجمعة", "يوم الأحد", "عند الظهر"], tier: .hard, grades: 4...6),
                BankQuestion(prompt: "لمن كان النباح الغريب؟", correctAnswer: "لابن آوى", distractors: ["لكلب", "لذئب", "لبومة"], tier: .hard, grades: 4...6),
                BankQuestion(prompt: "ماذا علّم الأب عن ابن آوى؟", correctAnswer: "أنّه يخاف منّا أكثر ممّا نخاف منه", distractors: ["أنّه خطير جدًّا", "أنّه ينام طوال الليل", "أنّه يحبّ الكشّافات"], tier: .hard, grades: 4...6),
            ]),
        ReadingPassage(
            id: "bread_bakery", tier: .hard,
            text: "هل تعرفون كيف يُصنع الخبز الذي نأكله؟ كلّ شيء يبدأ من حبّات القمح التي تنمو في الحقل. بعد الحصاد تُطحن الحبّات فيصير منها طحين أبيض ناعم. وفي المخبز يخلطون الطحين مع الماء والخميرة وقليل من الملح، ويعجنون عجينة طريّة. تحتاج العجينة إلى راحة نحو ساعة كي تنتفخ — فالخميرة تملؤها بفقاعات هواء صغيرة. عندها فقط يخبزونها في فرن حارّ، فتنتشر الرائحة الرائعة في الشارع كلّه.",
            questions: [
                BankQuestion(prompt: "ممّ يبدأ صنع الخبز؟", correctAnswer: "من حبّات القمح", distractors: ["من الأرزّ", "من البطاطا", "من السكّر"], tier: .hard, grades: 4...6),
                BankQuestion(prompt: "لماذا تحتاج العجينة إلى راحة؟", correctAnswer: "كي تنتفخ بفقاعات الهواء", distractors: ["كي تبرد", "كي تجفّ", "كي تغيّر لونها"], tier: .hard, grades: 4...6),
                BankQuestion(prompt: "ماذا يفعلون بالحبّات بعد الحصاد؟", correctAnswer: "يطحنونها ليصير منها طحين", distractors: ["يطبخونها", "يلوّنونها", "يزرعونها من جديد"], tier: .hard, grades: 4...6),
            ]),
        ReadingPassage(
            id: "dolphin_rescue", tier: .hard,
            text: "في صباح شتويّ وجد صيّادون على شاطئ عسقلان دلفينًا صغيرًا جرفته المياه إلى المياه الضحلة. اتّصلوا فورًا بمنقذي الطبيعة، فوصلوا بقارب خاصّ. وطوال ساعة كاملة حرص المنقذون على أن يبقى جلد الدلفين رطبًا، لأنّ الدلفين الذي يجفّ جلده يصبح في خطر كبير. وأخيرًا، حين ارتفع المدّ، نجحوا في إعادته بحذر إلى المياه العميقة. أطلق الصغير صفيرًا عاليًا — كأنّه شكر — واختفى بين الأمواج.",
            questions: [
                BankQuestion(prompt: "من وجد الدلفين الصغير؟", correctAnswer: "صيّادون", distractors: ["متنزّهون", "أولاد", "منقذون في المسبح"], tier: .hard, grades: 4...6),
                BankQuestion(prompt: "لماذا حرصوا على بقاء جلد الدلفين رطبًا؟", correctAnswer: "لأنّ الدلفين الذي يجفّ جلده يصبح في خطر", distractors: ["كي يشعر بالراحة", "كي ينظّفوه", "لأنّه يحبّ الماء البارد"], tier: .hard, grades: 4...6),
                BankQuestion(prompt: "متى أعادوه إلى المياه العميقة؟", correctAnswer: "حين ارتفع المدّ", distractors: ["في الليل", "فور أن وجدوه", "بعد أن أكل"], tier: .hard, grades: 4...6),
            ]),
        ReadingPassage(
            id: "old_clock", tier: .hard,
            text: "في عليّة بيت الجدّة وجدت ليان ساعة حائط عتيقة مغطّاة بالغبار. حكت الجدّة أنّ الساعة وصلت مع جدّ جدّها في سفينة، قبل أكثر من مئة سنة. كانت عقاربها قد توقّفت منذ زمن بعيد، لكنّ ليان لم تستسلم: نظّفتها بقطعة قماش ناعمة، وأحضر الأب قطعة جديدة لآليّتها. وفي مساء الجمعة، حين جلست العائلة كلّها إلى المائدة، أطلقت الساعة فجأة رنينًا عميقًا. ذرفت الجدّة دمعة — فهي لم تسمع هذا الصوت منذ كانت طفلة.",
            questions: [
                BankQuestion(prompt: "أين وجدت ليان الساعة؟", correctAnswer: "في عليّة البيت", distractors: ["في القبو", "في دكّان للأشياء العتيقة", "في الحديقة"], tier: .hard, grades: 4...6),
                BankQuestion(prompt: "كيف وصلت الساعة إلى العائلة؟", correctAnswer: "مع جدّ الجدّة، في سفينة", distractors: ["اشتُريت من السوق", "كانت هديّة من جار", "وصلت في رسالة من خارج البلاد"], tier: .hard, grades: 4...6),
                BankQuestion(prompt: "لماذا ذرفت الجدّة دمعة؟", correctAnswer: "لأنّها لم تسمع الرنين منذ طفولتها", distractors: ["لأنّ الساعة انكسرت", "لأنّها جرحت إصبعها", "لأنّ الطعام احترق"], tier: .hard, grades: 4...6),
            ]),
        ReadingPassage(
            id: "bee_dance", tier: .hard,
            text: "النحل من أنشط الحيوانات في الطبيعة، وله طريقة مدهشة في الحديث بعضه مع بعض. حين تجد النحلة حقلًا مليئًا بالأزهار، تعود إلى الخليّة وترقص رقصة خاصّة على شكل الرقم ثمانية. اتّجاه الرقصة يدلّ رفيقاتها على الجهة التي تطير إليها، وسرعة الاهتزاز تخبرهنّ كم يبعد الحقل. وهكذا، بلا كلمة واحدة، تعرف الخليّة كلّها إلى أين تخرج لجمع الرحيق.",
            questions: [
                BankQuestion(prompt: "كيف تخبر النحلة عن حقل الأزهار؟", correctAnswer: "برقصة على شكل الرقم ثمانية", distractors: ["بطنين قويّ", "بلمس الأجنحة", "بترك رائحة"], tier: .hard, grades: 4...6),
                BankQuestion(prompt: "على ماذا يدلّ اتّجاه الرقصة؟", correctAnswer: "على الجهة التي تطير إليها", distractors: ["على عدد النحلات اللواتي يأتين", "على لون الأزهار", "على موعد الخروج"], tier: .hard, grades: 4...6),
                BankQuestion(prompt: "ماذا تخبر سرعة الاهتزاز؟", correctAnswer: "كم يبعد الحقل", distractors: ["كم رحيقًا هناك", "ما حالة الطقس", "من هي الملكة"], tier: .hard, grades: 4...6),
            ]),
        ReadingPassage(
            id: "kite_contest", tier: .hard,
            text: "في عطلة عيد الفطر أُقيمت في القرية مسابقة كبيرة للطائرات الورقيّة. عمل كرم على طائرته أسبوعًا كاملًا: هيكل من قصبات الخيزران الخفيفة، وورق حرير برتقاليّ، وذيل طويل من شرائط ملوّنة. في يوم المسابقة لم تهبّ الريح تقريبًا، فسقطت طائرات كثيرة إلى الأرض. أمّا طائرة كرم الخفيفة فنجحت في الصعود عاليًا عاليًا، حتّى بدت نقطة برتقاليّة صغيرة في السماء. ومنحها الحكّام جائزة «الأعلى ارتفاعًا».",
            questions: [
                BankQuestion(prompt: "ممّ صُنع هيكل الطائرة الورقيّة؟", correctAnswer: "من قصبات الخيزران", distractors: ["من الحديد", "من البلاستيك", "من أغصان ثقيلة"], tier: .hard, grades: 4...6),
                BankQuestion(prompt: "لماذا سقطت طائرات كثيرة؟", correctAnswer: "لأنّ الريح لم تهبّ تقريبًا", distractors: ["لأنّ المطر نزل", "لأنّ الخيوط انقطعت", "لأنّ الظلام حلّ"], tier: .hard, grades: 4...6),
                BankQuestion(prompt: "أيّ جائزة نالها كرم؟", correctAnswer: "«الأعلى ارتفاعًا»", distractors: ["«الأجمل»", "«الأسرع»", "«الأكبر»"], tier: .hard, grades: 4...6),
            ]),
        ReadingPassage(
            id: "x_bird_window", tier: .easy, grades: 1...2,
            text: "حطّ عصفور صغير على حافّة النافذة. غرّد أغنية قصيرة وطار بعيدًا.",
            questions: [
                BankQuestion(prompt: "أين حطّ العصفور؟", correctAnswer: "على حافّة النافذة", distractors: ["على الشجرة", "على السطح", "على الكرسيّ"], tier: .easy, grades: 1...2),
                BankQuestion(prompt: "ماذا فعل العصفور؟", correctAnswer: "غرّد أغنية", distractors: ["بنى عشًّا", "أكل دودة", "نام"], tier: .easy, grades: 1...2),
            ]),
        ReadingPassage(
            id: "x_new_shoes", tier: .easy, grades: 1...2,
            text: "عند سارة حذاء جديد لونه أزرق. ركضت به بسرعة في الساحة.",
            questions: [
                BankQuestion(prompt: "ما لون الحذاء؟", correctAnswer: "أزرق", distractors: ["أحمر", "أخضر", "ورديّ"], tier: .easy, grades: 1...2),
                BankQuestion(prompt: "ماذا فعلت سارة بالحذاء؟", correctAnswer: "ركضت في الساحة", distractors: ["لعبت في الرمل", "جلست في البيت", "قفزت على السرير"], tier: .easy, grades: 1...2),
            ]),
        ReadingPassage(
            id: "x_two_cats", tier: .easy, grades: 1...2,
            text: "عند نور قطّتان، واحدة بيضاء وواحدة سوداء. تحبّان اللعب بكرة من صوف.",
            questions: [
                BankQuestion(prompt: "كم قطّة عند نور؟", correctAnswer: "قطّتان", distractors: ["قطّة واحدة", "ثلاث قطط", "أربع قطط"], tier: .easy, grades: 1...2),
                BankQuestion(prompt: "بماذا تحبّ القطّتان أن تلعبا؟", correctAnswer: "بكرة من صوف", distractors: ["بعصا", "بالماء", "بالأوراق"], tier: .easy, grades: 1...2),
            ]),
        ReadingPassage(
            id: "x_apple_tree", tier: .easy, grades: 1...2,
            text: "في ساحة الروضة شجرة تفّاح كبيرة. في الخريف سقطت منها تفّاحات حمراء على الأرض.",
            questions: [
                BankQuestion(prompt: "أيّ شجرة في الساحة؟", correctAnswer: "شجرة تفّاح", distractors: ["شجرة زيتون", "شجرة سنديان", "شجرة نخيل"], tier: .easy, grades: 1...2),
                BankQuestion(prompt: "متى سقطت التفّاحات؟", correctAnswer: "في الخريف", distractors: ["في الصيف", "في الربيع", "في الشتاء"], tier: .easy, grades: 1...2),
            ]),
        ReadingPassage(
            id: "x_teeth_brush", tier: .easy, grades: 1...2,
            text: "قبل النوم ينظّف آدم أسنانه بفرشاة ومعجون. هكذا تبقى أسنانه قويّة وسليمة.",
            questions: [
                BankQuestion(prompt: "متى ينظّف آدم أسنانه؟", correctAnswer: "قبل النوم", distractors: ["عند الظهر", "في الروضة", "بعد اللعب"], tier: .easy, grades: 1...2),
                BankQuestion(prompt: "لماذا من الجيّد تنظيف الأسنان؟", correctAnswer: "كي تبقى قويّة وسليمة", distractors: ["كي تصير ملوّنة", "كي ننام بسرعة", "كي نكبر"], tier: .easy, grades: 1...2),
            ]),
        ReadingPassage(
            id: "x_grandma_soup", tier: .easy, grades: 1...2,
            text: "طبخت الجدّة حساء خضار ساخنًا. وجلست العائلة كلّها لتأكل معًا حول المائدة.",
            questions: [
                BankQuestion(prompt: "ماذا طبخت الجدّة؟", correctAnswer: "حساء خضار", distractors: ["كعكة", "بيتزا", "أرزّ"], tier: .easy, grades: 1...2),
                BankQuestion(prompt: "من جلس ليأكل؟", correctAnswer: "العائلة كلّها", distractors: ["الجدّة وحدها", "الأولاد فقط", "الجيران"], tier: .easy, grades: 1...2),
            ]),
        ReadingPassage(
            id: "x_lost_balloon", tier: .easy, grades: 1...2,
            text: "هرب بالون كرم الأحمر إلى السماء. لوّح له كرم بيده وابتسم.",
            questions: [
                BankQuestion(prompt: "إلى أين هرب البالون؟", correctAnswer: "إلى السماء", distractors: ["إلى البحر", "تحت السرير", "إلى الحديقة"], tier: .easy, grades: 1...2),
                BankQuestion(prompt: "ماذا فعل كرم؟", correctAnswer: "لوّح له بيده وابتسم", distractors: ["بكى", "ركض خلفه", "غضب"], tier: .easy, grades: 1...2),
            ]),
        ReadingPassage(
            id: "x_school_bus", tier: .medium, grades: 2...3,
            text: "في كلّ صباح يصعد رامي إلى حافلة المدرسة الصفراء. السائق سامي يبتسم ويقول «صباح الخير» لكلّ ولد. يحبّ رامي أن يجلس قرب النافذة وأن يعدّ كم كلبًا يرى في الطريق.",
            questions: [
                BankQuestion(prompt: "ما لون الحافلة؟", correctAnswer: "أصفر", distractors: ["أزرق", "أحمر", "أخضر"], tier: .medium, grades: 2...3),
                BankQuestion(prompt: "ماذا يقول السائق لكلّ ولد؟", correctAnswer: "صباح الخير", distractors: ["تصبح على خير", "إلى اللقاء", "شكرًا"], tier: .medium, grades: 2...3),
                BankQuestion(prompt: "ماذا يعدّ رامي في الطريق؟", correctAnswer: "كم كلبًا يرى", distractors: ["كم سيّارة يرى", "كم شجرة يرى", "كم صديقًا يرى"], tier: .medium, grades: 2...3),
            ]),
        ReadingPassage(
            id: "x_seasons_tree", tier: .medium, grades: 2...3,
            text: "في الربيع تمتلئ الشجرة بأزهار ورديّة. وفي الصيف تنمو عليها أوراق خضراء ونضرة، وفي الخريف تصفرّ الأوراق وتتساقط. وفي الشتاء تبقى الشجرة عارية، وتنتظر بصبر عودة الربيع.",
            questions: [
                BankQuestion(prompt: "متى تمتلئ الشجرة بالأزهار؟", correctAnswer: "في الربيع", distractors: ["في الشتاء", "في الصيف", "في الخريف"], tier: .medium, grades: 2...3),
                BankQuestion(prompt: "ماذا يحدث للأوراق في الخريف؟", correctAnswer: "تصفرّ وتتساقط", distractors: ["تبقى خضراء", "تتحوّل إلى أزهار", "تكبر كثيرًا"], tier: .medium, grades: 2...3),
                BankQuestion(prompt: "كيف تبدو الشجرة في الشتاء؟", correctAnswer: "عارية بلا أوراق", distractors: ["مليئة بالثمار", "مغطّاة بأوراق خضراء", "محمّلة بالأزهار"], tier: .medium, grades: 2...3),
            ]),
        ReadingPassage(
            id: "x_firefighter", tier: .medium, grades: 2...3,
            text: "حين اندلع حريق صغير في الحيّ، وصل رجال الإطفاء بسيّارة حمراء كبيرة. وصلوا خرطومًا طويلًا بالصنبور وأطفأوا النار بماء كثير. وفي النهاية صفّق لهم الجميع وقالوا شكرًا.",
            questions: [
                BankQuestion(prompt: "بماذا وصل رجال الإطفاء؟", correctAnswer: "بسيّارة حمراء", distractors: ["بدرّاجة هوائيّة", "على الأقدام", "بحافلة"], tier: .medium, grades: 2...3),
                BankQuestion(prompt: "كيف أطفأوا النار؟", correctAnswer: "بالماء عبر خرطوم", distractors: ["بالرمل", "بالريح", "ببطّانيّة"], tier: .medium, grades: 2...3),
                BankQuestion(prompt: "ماذا فعل الناس في النهاية؟", correctAnswer: "صفّقوا وقالوا شكرًا", distractors: ["هربوا إلى بيوتهم", "غضبوا", "أشعلوا نارًا جديدة"], tier: .medium, grades: 2...3),
            ]),
        ReadingPassage(
            id: "x_honey_holiday", tier: .medium, grades: 2...3,
            text: "في عيد الفطر تحضّر العائلة مائدة حلوة: يغمسون شرائح التفّاح في العسل ويتمنّون لبعضهم عيدًا سعيدًا وأيّامًا حلوة. ساعد كرم أمّه في ترتيب المائدة، ووضع رمّانة حمراء في الوسط. واجتمعت العائلة كلّها معًا على طعام العيد.",
            questions: [
                BankQuestion(prompt: "بماذا يغمسون التفّاح؟", correctAnswer: "بالعسل", distractors: ["بالملح", "بالزيت", "بالماء"], tier: .medium, grades: 2...3),
                BankQuestion(prompt: "ماذا وضع كرم في الوسط؟", correctAnswer: "رمّانة حمراء", distractors: ["شمعة", "زهرة", "كعكة"], tier: .medium, grades: 2...3),
                BankQuestion(prompt: "أيّ عيد يصفه النصّ؟", correctAnswer: "عيد الفطر", distractors: ["عيد الأضحى", "رأس السنة الميلاديّة", "عيد الأمّ"], tier: .medium, grades: 2...3),
            ]),
        ReadingPassage(
            id: "x_water_cycle", tier: .medium, grades: 3...4,
            text: "الماء في الطبيعة في رحلة دائمة. تسخّن الشمس ماء البحر، فيتبخّر ويصعد إلى السماء على شكل بخار رقيق. وهناك يبرد البخار ويتحوّل إلى غيوم، وحين تصير الغيوم ثقيلة بما يكفي — ينزل المطر. ويملأ المطر الجداول والبحر من جديد، وتبدأ الرحلة من أوّلها.",
            questions: [
                BankQuestion(prompt: "ماذا يحدث لماء البحر حين تسخّنه الشمس؟", correctAnswer: "يتبخّر ويصعد إلى السماء", distractors: ["يتجمّد", "يختفي إلى الأبد", "يتحوّل إلى ملح"], tier: .medium, grades: 3...4),
                BankQuestion(prompt: "ممّ تتكوّن الغيوم؟", correctAnswer: "من بخار يبرد", distractors: ["من الغبار", "من الدخان", "من حبّات الرمل"], tier: .medium, grades: 3...4),
                BankQuestion(prompt: "متى ينزل المطر؟", correctAnswer: "حين تصير الغيوم ثقيلة بما يكفي", distractors: ["حين يشتدّ الحرّ", "حين تشرق الشمس", "حين تهبّ الريح"], tier: .medium, grades: 3...4),
            ]),
        ReadingPassage(
            id: "x_magnet", tier: .medium, grades: 3...4,
            text: "المغناطيس قطعة معدن خاصّة تجذب إليها الحديد. ولكلّ مغناطيس قطبان — شماليّ وجنوبيّ. حين نقرّب قطبين مختلفين ينجذب أحدهما إلى الآخر، أمّا القطبان المتشابهان فيتنافران.",
            questions: [
                BankQuestion(prompt: "أيّ معدن يجذب المغناطيس؟", correctAnswer: "الحديد", distractors: ["الذهب", "الفضّة", "النحاس"], tier: .medium, grades: 3...4),
                BankQuestion(prompt: "كم قطبًا لكلّ مغناطيس؟", correctAnswer: "قطبان", distractors: ["قطب واحد", "ثلاثة أقطاب", "أربعة أقطاب"], tier: .medium, grades: 3...4),
                BankQuestion(prompt: "ماذا يحدث بين قطبين متشابهين؟", correctAnswer: "يتنافران", distractors: ["ينجذبان أحدهما إلى الآخر", "لا يحدث شيء", "يلتصقان إلى الأبد"], tier: .medium, grades: 3...4),
            ]),
        ReadingPassage(
            id: "x_jerusalem", tier: .medium, grades: 3...4,
            text: "القدس هي عاصمة دولة إسرائيل، وهي من أقدم مدن العالم. في البلدة القديمة سور كبير وأبواب كثيرة. وفي القدس توجد مؤسّسات الحكم في الدولة، ومنها الكنيست.",
            questions: [
                BankQuestion(prompt: "ما هي القدس؟", correctAnswer: "عاصمة إسرائيل", distractors: ["مدينة ميناء", "قرية صغيرة", "جزيرة في البحر"], tier: .medium, grades: 3...4),
                BankQuestion(prompt: "ماذا يحيط بالبلدة القديمة؟", correctAnswer: "سور كبير", distractors: ["غابة", "نهر", "صحراء"], tier: .medium, grades: 3...4),
                BankQuestion(prompt: "أيّ مؤسّسة حكم توجد في القدس؟", correctAnswer: "الكنيست", distractors: ["الميناء", "المطار", "الجامعة وحدها"], tier: .medium, grades: 3...4),
            ]),
        ReadingPassage(
            id: "x_ant_colony", tier: .medium, grades: 3...4,
            text: "يعيش النمل في مستعمرات كبيرة، غالبًا تحت الأرض. ولكلّ نملة دور خاصّ: الشغّالات تجمع الغذاء وتعتني بالعشّ، والملكة تضع البيض. يتعاون النمل، وهكذا ينجح في حمل طعام ثقيل معًا.",
            questions: [
                BankQuestion(prompt: "أين يعيش معظم النمل؟", correctAnswer: "تحت الأرض", distractors: ["على أشجار عالية", "داخل الماء", "في الغيوم"], tier: .medium, grades: 3...4),
                BankQuestion(prompt: "ما دور الملكة؟", correctAnswer: "أن تضع البيض", distractors: ["أن تجمع الغذاء", "أن تحرس المدخل", "أن تبني الممرّات"], tier: .medium, grades: 3...4),
                BankQuestion(prompt: "كيف ينجح النمل في حمل طعام ثقيل؟", correctAnswer: "بالتعاون معًا", distractors: ["كلّ نملة وحدها", "لا ينجح في ذلك", "بمساعدة الريح"], tier: .medium, grades: 3...4),
            ]),
        ReadingPassage(
            id: "x_volcano", tier: .medium, grades: 3...4,
            text: "البركان جبل خاصّ تندفع منه أحيانًا حمم حارقة. والحمم صخر ذاب من حرارة هائلة في عمق الأرض. وحين تخرج الحمم إلى الخارج وتبرد، تعود فتتحوّل إلى صخر صلب.",
            questions: [
                BankQuestion(prompt: "ماذا يندفع من البركان؟", correctAnswer: "حمم حارقة", distractors: ["ماء بارد", "ثلج", "رمل"], tier: .medium, grades: 3...4),
                BankQuestion(prompt: "ما هي الحمم؟", correctAnswer: "صخر ذاب من الحرارة", distractors: ["ماء مالح", "هواء ساخن", "طين عاديّ"], tier: .medium, grades: 3...4),
                BankQuestion(prompt: "ماذا يحدث للحمم حين تبرد؟", correctAnswer: "تتحوّل إلى صخر صلب", distractors: ["تختفي", "تتحوّل إلى ماء", "تصعد إلى السماء"], tier: .medium, grades: 3...4),
            ]),
        ReadingPassage(
            id: "x_photosynthesis", tier: .hard, grades: 4...5,
            text: "النباتات من الكائنات القليلة في الطبيعة التي تعرف أن تصنع غذاءها بنفسها. في الأوراق الخضراء مادّة اسمها الكلوروفيل، وهي تمتصّ ضوء الشمس. وبمساعدة الضوء والماء وثاني أكسيد الكربون الموجود في الهواء، يصنع النبات سكّرًا ليتغذّى، ويطلق الأكسجين إلى الهواء. وهكذا توفّر لنا النباتات الأكسجين الذي نتنفّسه.",
            questions: [
                BankQuestion(prompt: "أيّ مادّة في الأوراق تمتصّ ضوء الشمس؟", correctAnswer: "الكلوروفيل", distractors: ["السكّر", "الملح", "الحديد"], tier: .hard, grades: 4...5),
                BankQuestion(prompt: "ماذا يصنع النبات ليتغذّى؟", correctAnswer: "سكّرًا", distractors: ["ماءً", "رملًا", "حجرًا"], tier: .hard, grades: 4...5),
                BankQuestion(prompt: "أيّ غاز تطلقه النباتات إلى الهواء؟", correctAnswer: "الأكسجين", distractors: ["الدخان", "بخار الماء", "ثاني أكسيد الكربون"], tier: .hard, grades: 4...5),
            ]),
        ReadingPassage(
            id: "x_maccabi_history", tier: .hard, grades: 4...5,
            text: "قبل أكثر من ثمانمئة سنة كان الصليبيّون يحكمون مدن البلاد، ومنها القدس. جمع القائد صلاح الدين الأيّوبيّ جيشًا كبيرًا، والتقى بهم قرب قرن حطّين في الجليل، غير بعيد عن بحيرة طبريّا. كان النهار شديد الحرّ والماء قليلًا، فانتصر جيش صلاح الدين في تلك المعركة، ودخل القدس بعدها بأشهر قليلة. وما زالت معركة حطّين تُذكر في كتب التاريخ حتّى اليوم.",
            questions: [
                BankQuestion(prompt: "من كان يحكم مدن البلاد قبل المعركة؟", correctAnswer: "الصليبيّون", distractors: ["الرومان", "اليونانيّون", "البابليّون"], tier: .hard, grades: 4...5),
                BankQuestion(prompt: "من قاد الجيش الذي حارب الصليبيّين؟", correctAnswer: "صلاح الدين الأيّوبيّ", distractors: ["هارون الرشيد", "طارق بن زياد", "الملك فيصل"], tier: .hard, grades: 4...5),
                BankQuestion(prompt: "أين دارت المعركة؟", correctAnswer: "قرب قرن حطّين في الجليل", distractors: ["في النقب", "على شاطئ يافا", "قرب البحر الميّت"], tier: .hard, grades: 4...5),
            ]),
        ReadingPassage(
            id: "x_desert_animals", tier: .hard, grades: 4...5,
            text: "في الصحراء الحارّة تعلّمت حيوانات كثيرة أن تعيش بلا ماء تقريبًا. يخزّن الجمل الشحم في السنام الذي على ظهره، وهكذا يستطيع أن يسير أيّامًا كثيرة بلا شرب. وكثير من الحيوانات الصغيرة تختبئ في النهار ولا تخرج إلّا في الليل البارد، كي لا تجفّ من الحرّ.",
            questions: [
                BankQuestion(prompt: "ماذا يخزّن الجمل في السنام؟", correctAnswer: "الشحم", distractors: ["الماء", "طعامًا طازجًا", "الرمل"], tier: .hard, grades: 4...5),
                BankQuestion(prompt: "لماذا تخرج الحيوانات الصغيرة في الليل؟", correctAnswer: "كي لا تجفّ من الحرّ", distractors: ["لأنّ الطعام أكثر حينها", "لأنّها تحبّ الظلام", "لأنّ النهار بارد"], tier: .hard, grades: 4...5),
                BankQuestion(prompt: "ما المشترك بين حيوانات الصحراء؟", correctAnswer: "تعلّمت أن تعيش بلا ماء تقريبًا", distractors: ["كلّها تسبح", "كلّها تطير", "كلّها كبيرة جدًّا"], tier: .hard, grades: 4...5),
            ]),
        ReadingPassage(
            id: "x_blood_circulation", tier: .hard, grades: 5...6,
            text: "القلب عضلة قويّة تعمل بلا توقّف، ليلًا ونهارًا. وظيفته أن يضخّ الدم إلى كلّ أنحاء الجسم عبر أنابيب دقيقة تُسمّى الأوعية الدمويّة. يحمل الدم الأكسجين والغذاء إلى كلّ خليّة في الجسم، وفي طريق العودة يُخلّص الجسم من الفضلات. ولولا هذا النشاط لما استطاع الجسم أن يؤدّي عمله ولو للحظة واحدة.",
            questions: [
                BankQuestion(prompt: "ماذا يضخّ القلب في الجسم؟", correctAnswer: "الدم", distractors: ["الهواء", "الماء", "الطعام الصلب"], tier: .hard, grades: 5...6),
                BankQuestion(prompt: "ما اسم الأنابيب التي يمرّ الدم فيها؟", correctAnswer: "الأوعية الدمويّة", distractors: ["الأعصاب", "الأوتار", "العظام"], tier: .hard, grades: 5...6),
                BankQuestion(prompt: "ماذا يحمل الدم إلى الخلايا؟", correctAnswer: "الأكسجين والغذاء", distractors: ["الماء وحده", "الفضلات فقط", "الحرارة"], tier: .hard, grades: 5...6),
            ]),
        ReadingPassage(
            id: "x_water_states", tier: .hard, grades: 5...6,
            text: "للماء ثلاث حالات: صلبة وسائلة وغازيّة. حين يتجمّد الماء في البرد الشديد يتحوّل إلى جليد صلب. وحين نُسخّنه يعود سائلًا، وإذا واصلنا تسخينه حتّى الغليان تبخّر وتحوّل إلى بخار. ومن المثير أنّ المادّة نفسها يمكن أن تظهر في ثلاث صور مختلفة تمامًا.",
            questions: [
                BankQuestion(prompt: "كم حالة للماء؟", correctAnswer: "ثلاث", distractors: ["اثنتان", "أربع", "واحدة"], tier: .hard, grades: 5...6),
                BankQuestion(prompt: "إلى ماذا يتحوّل الماء في البرد الشديد؟", correctAnswer: "إلى جليد صلب", distractors: ["إلى بخار", "إلى ملح", "إلى طين"], tier: .hard, grades: 5...6),
                BankQuestion(prompt: "ماذا يحدث للماء عند الغليان؟", correctAnswer: "يتبخّر ويتحوّل إلى بخار", distractors: ["يتجمّد", "يختفي تمامًا", "يتحوّل إلى جليد"], tier: .hard, grades: 5...6),
            ]),
        ReadingPassage(
            id: "x_recycling", tier: .hard, grades: 5...6,
            text: "إعادة التدوير طريقة مهمّة للمحافظة على الكرة الأرضيّة. فبدل رمي القناني والورق والبلاستيك في سلّة النفايات، يمكن جمعها وتحويلها إلى منتجات جديدة. وهكذا نوفّر الموادّ الخام والطاقة، ونقلّل كمّيّة النفايات التي تتراكم في الطبيعة وتلوّثها.",
            questions: [
                BankQuestion(prompt: "ما هدف إعادة التدوير؟", correctAnswer: "المحافظة على الكرة الأرضيّة", distractors: ["ربح المال بسرعة", "ملء سلال النفايات", "إنتاج نفايات أكثر"], tier: .hard, grades: 5...6),
                BankQuestion(prompt: "ماذا نفعل بالموادّ بدل رميها؟", correctAnswer: "نحوّلها إلى منتجات جديدة", distractors: ["نحرقها", "ندفنها في البحر", "نتركها في الطبيعة"], tier: .hard, grades: 5...6),
                BankQuestion(prompt: "ماذا نوفّر بفضل إعادة التدوير؟", correctAnswer: "الموادّ الخام والطاقة", distractors: ["وقت الفراغ", "مكانًا في البيت", "المال وحده"], tier: .hard, grades: 5...6),
            ]),
        ReadingPassage(
            id: "x_moon_phases", tier: .hard, grades: 5...6,
            text: "يدور القمر حول الكرة الأرضيّة مرّة في الشهر تقريبًا. وهو لا يضيء من نفسه، بل يعكس إلينا ضوء الشمس. وبحسب موقعه في مداره نرى في كلّ مرّة جزءًا مختلفًا منه مضيئًا — فمرّة هلالًا رفيعًا ومرّة قمرًا بدرًا مستديرًا.",
            questions: [
                BankQuestion(prompt: "كلّ كم من الوقت يدور القمر حول الكرة الأرضيّة؟", correctAnswer: "مرّة في الشهر تقريبًا", distractors: ["مرّة في اليوم", "مرّة في السنة", "مرّة في الأسبوع"], tier: .hard, grades: 5...6),
                BankQuestion(prompt: "من أين يأتي ضوء القمر؟", correctAnswer: "يعكس ضوء الشمس", distractors: ["يضيء من نفسه", "من النجوم", "من الكرة الأرضيّة"], tier: .hard, grades: 5...6),
                BankQuestion(prompt: "لماذا نرى شكل القمر متغيّرًا؟", correctAnswer: "بسبب موقعه في مداره", distractors: ["لأنّه يكبر ويصغر", "لأنّ الغيوم تغطّيه", "لأنّه يبتعد عنّا"], tier: .hard, grades: 5...6),
            ]),
        ReadingPassage(
            id: "x_democracy", tier: .hard, grades: 6...6,
            text: "في الدولة الديمقراطيّة المواطنون هم الذين يختارون قادتهم. فكلّ بضع سنوات تُجرى انتخابات، ولكلّ مواطن بالغ حقّ التصويت. والفكرة المركزيّة هي أنّ لكلّ إنسان حقوقًا متساوية، وأنّ على الحكم أن يعمل لمصلحة الجمهور كلّه لا لمصلحة قلّة فقط.",
            questions: [
                BankQuestion(prompt: "من يختار القادة في الدولة الديمقراطيّة؟", correctAnswer: "المواطنون", distractors: ["الملك", "الجيش", "القضاة"], tier: .hard, grades: 6...6),
                BankQuestion(prompt: "متى تُجرى الانتخابات؟", correctAnswer: "كلّ بضع سنوات", distractors: ["كلّ يوم", "مرّة واحدة في العمر", "لا تُجرى أبدًا"], tier: .hard, grades: 6...6),
                BankQuestion(prompt: "ما الفكرة المركزيّة للديمقراطيّة؟", correctAnswer: "لكلّ إنسان حقوق متساوية", distractors: ["القويّ هو الذي يحكم", "لا حقوق لأحد", "الأغنياء وحدهم ينتخبون"], tier: .hard, grades: 6...6),
            ]),
        ReadingPassage(
            id: "x_rainforest", tier: .hard, grades: 6...6,
            text: "الغابات المطيرة من أغنى الأماكن بالحياة على وجه الكرة الأرضيّة. تعيش فيها ملايين الأنواع من النباتات والحيوانات، وكثير منها لا يوجد في أيّ مكان آخر. وتُنتج أشجارها العالية جزءًا كبيرًا من الأكسجين في العالم، ولذلك يسمّونها أحيانًا «رئتَي الكرة الأرضيّة». وقطعُ الغابات يهدّد هذا التوازن الدقيق.",
            questions: [
                BankQuestion(prompt: "بماذا تغتني الغابات المطيرة؟", correctAnswer: "بأنواع كثيرة من الكائنات الحيّة", distractors: ["بالذهب", "بالمياه المالحة", "بالرمل"], tier: .hard, grades: 6...6),
                BankQuestion(prompt: "لماذا تُسمّى «رئتَي الكرة الأرضيّة»؟", correctAnswer: "لأنّها تنتج كثيرًا من الأكسجين", distractors: ["لأنّ شكلها كشكل الرئة", "لأنّها تتنفّس", "لأنّها رطبة"], tier: .hard, grades: 6...6),
                BankQuestion(prompt: "ما الذي يهدّد الغابات المطيرة؟", correctAnswer: "قطع الأشجار", distractors: ["كثرة المطر", "الحيوانات الصغيرة", "ضوء الشمس"], tier: .hard, grades: 6...6),
            ]),
        ReadingPassage(
            id: "x_gutenberg", tier: .hard, grades: 6...6,
            text: "قبل نحو خمسمئة سنة كان كلّ كتاب يُكتب باليد، ولذلك كانت الكتب غالية ونادرة جدًّا. ثمّ اخترع رجل اسمه غوتنبرغ مطبعة ذات حروف متحرّكة. وأتاح هذا الاختراع طبع كتب كثيرة بسرعة وبثمن زهيد، وهكذا انتشرت المعرفة والثقافة في العالم كلّه.",
            questions: [
                BankQuestion(prompt: "كيف كانت الكتب تُكتب قبل الاختراع؟", correctAnswer: "باليد", distractors: ["بالآلة الكاتبة", "بالحاسوب", "لم تكن هناك كتب"], tier: .hard, grades: 6...6),
                BankQuestion(prompt: "ماذا اخترع غوتنبرغ؟", correctAnswer: "مطبعة", distractors: ["آلة تصوير", "هاتفًا", "قلم رصاص"], tier: .hard, grades: 6...6),
                BankQuestion(prompt: "ما نتيجة الاختراع؟", correctAnswer: "انتشرت المعرفة والثقافة", distractors: ["صارت الكتب أغلى", "توقّف الناس عن القراءة", "لم يتغيّر شيء"], tier: .hard, grades: 6...6),
            ]),
        ReadingPassage(
            id: "x_dead_sea", tier: .hard, grades: 5...6,
            text: "البحر الميت هو أخفض مكان على سطح اليابسة في العالم — أكثر من أربعمئة متر تحت سطح البحر. ومياهه أشدّ ملوحة بأضعاف من مياه البحر العاديّ، ولذلك يسهل جدًّا الطفو فيها. ولا تستطيع الكائنات الحيّة أن تعيش في هذه المياه شديدة الملوحة، ومن هنا جاء اسمه «البحر الميت».",
            questions: [
                BankQuestion(prompt: "ما المميّز في موقع البحر الميت من حيث الارتفاع؟", correctAnswer: "هو أخفض مكان على اليابسة", distractors: ["هو الأعلى في العالم", "هو تمامًا في مستوى سطح البحر", "هو على قمّة جبل"], tier: .hard, grades: 5...6),
                BankQuestion(prompt: "لماذا يسهل الطفو في البحر الميت؟", correctAnswer: "لأنّ مياهه شديدة الملوحة", distractors: ["لأنّ مياهه ضحلة", "لأنّ مياهه دافئة", "لأنّ فيه أمواجًا عالية"], tier: .hard, grades: 5...6),
                BankQuestion(prompt: "لماذا سُمّي «البحر الميت» بهذا الاسم؟", correctAnswer: "لأنّ الكائنات الحيّة لا تستطيع العيش فيه", distractors: ["لأنّ السباحة فيه خطيرة", "لأنّ مياهه سوداء", "لأنّه جافّ تمامًا"], tier: .hard, grades: 5...6),
            ]),
        ReadingPassage(
            id: "ms7_bees", tier: .medium, grades: 7...7,
            text: "حين تنتقل النحلة من زهرة إلى زهرة لتجمع الرحيق، تعلق حبوب اللقاح بالشعيرات التي على جسمها. وفي الزهرة التالية يسقط جزء من اللقاح، فتُلقَّح الزهرة. وبفضل التلقيح تستطيع الزهرة أن تتحوّل إلى ثمرة وتُنبت بذورًا. ويعتمد جزء كبير من الفواكه والخضار التي نأكلها على تلقيح الحشرات، وعلى النحل بصورة خاصّة. وفي السنوات الأخيرة يُبلّغ العلماء عن انخفاض في عدد النحل في مناطق كثيرة من العالم. ومن الأسباب التي يذكرونها: استعمال المبيدات، والأمراض، وقلّة الأزهار البرّيّة.",
            questions: [
                BankQuestion(prompt: "بحسب النصّ، ماذا تأتي النحلة لتجمعه من الأزهار؟", correctAnswer: "الرحيق", distractors: ["البذور", "الماء", "الأوراق"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "ماذا يحدث بفضل التلقيح؟", correctAnswer: "تستطيع الزهرة أن تتحوّل إلى ثمرة", distractors: ["تذبل الزهرة أسرع", "تحصل النحلة على طاقة", "تغيّر الزهرة لونها"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "أيّ سبب لانخفاض عدد النحل لا يَرِد في النصّ؟", correctAnswer: "الطقس البارد", distractors: ["استعمال المبيدات", "الأمراض", "قلّة الأزهار البرّيّة"], tier: .hard, grades: 7...7),
                BankQuestion(prompt: "ماذا يمكن أن نستنتج من النصّ؟", correctAnswer: "انخفاض عدد النحل قد يضرّ بغذائنا", distractors: ["بلا نحل لن تكون هناك أزهار إطلاقًا", "الفواكه والخضار تنمو دون حاجة إلى تلقيح", "النحل وحده يستطيع تلقيح الأزهار"], tier: .hard, grades: 7...7),
            ]),
        ReadingPassage(
            id: "ms7_pompeii", tier: .medium, grades: 7...7,
            text: "في سنة 79 للميلاد ثار بركان فيزوف في جنوب إيطاليا. غطّت سحابة ضخمة من الرماد والصخور المتّقدة مدينة بومبي الرومانيّة، فدُفنت تحت طبقة سميكة. ومرّت مئات السنين دون أن يعرف أحد أين كانت المدينة بالضبط. وفي القرن الثامن عشر فقط بدأت حفريّات منظّمة في المكان. والعجيب أنّ الكارثة نفسها هي التي حفظت المدينة: فقد حمى الرماد البيوت والرسوم الجداريّة وأدوات البيت، وحتّى أرغفة الخبز. ولهذا تُعدّ بومبي من أهمّ المصادر لدراسة الحياة اليوميّة في روما القديمة.",
            questions: [
                BankQuestion(prompt: "ما الذي أدّى إلى دفن بومبي؟", correctAnswer: "ثوران بركان", distractors: ["زلزال قويّ", "فيضان نهر", "حرب مع جيش أجنبيّ"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "متى بدأت الحفريّات المنظّمة في بومبي، بحسب النصّ؟", correctAnswer: "في القرن الثامن عشر", distractors: ["بعد الكارثة مباشرة", "في القرن الأوّل", "في السنوات الأخيرة فقط"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "لماذا يقول الكاتب إنّ «الكارثة نفسها هي التي حفظت المدينة»؟", correctAnswer: "لأنّ الرماد حمى ما كان في المدينة", distractors: ["لأنّ السكّان تمكّنوا من الهرب", "لأنّ البركان توقّف عن الثوران", "لأنّ الرومان بنوها من جديد"], tier: .hard, grades: 7...7),
                BankQuestion(prompt: "لماذا تُعدّ بومبي مهمّة للباحثين اليوم؟", correctAnswer: "لأنّها تعلّمنا عن الحياة اليوميّة في روما", distractors: ["لأنّها كانت عاصمة الإمبراطوريّة", "لأنّ فيها أعلى بركان في العالم", "لأنّها المدينة القديمة الوحيدة في إيطاليا"], tier: .hard, grades: 7...7),
            ]),
        ReadingPassage(
            id: "ms7_race", tier: .medium, grades: 7...7,
            text: "تدرّبت ليان شهرين استعدادًا لسباق الحيّ. وفي صباح السباق شعرت بأنّ ساقيها ثقيلتان، لكنّها قرّرت أن تركض رغم ذلك. وبعد كيلومترين رأت مريم، صديقتها من الصفّ، جالسة على جانب الطريق تمسك كاحلها. توقّفت ليان. قالت لها مريم: «اذهبي، ستخسرين وقتك». فكّرت ليان لحظة، ثمّ جلست إلى جانبها ونادت أحد المتطوّعين. وأنهت السباق في المراكز الأخيرة تقريبًا. وفي المساء، حين سألتها أمّها إن كانت خائبة الأمل، ابتسمت ليان وقالت: «بالعكس، اليوم ركضت بأسرع ما أستطيع — نحو مريم».",
            questions: [
                BankQuestion(prompt: "ماذا حدث لمريم أثناء السباق؟", correctAnswer: "أُصيبت في كاحلها", distractors: ["وصلت إلى خطّ النهاية أولى", "تعبت وعادت إلى البيت", "تاهت عن الطريق"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "بماذا أشارت مريم على ليان؟", correctAnswer: "أن تواصل الركض دون أن تنتظرها", distractors: ["أن تتّصل بأمّها", "أن تساعدها على المشي", "أن تتخلّى عن السباق"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "ماذا تقصد ليان بقولها «ركضت بأسرع ما أستطيع — نحو مريم»؟", correctAnswer: "أنّ مساعدة الصديقة كانت أهمّ عندها من النتيجة", distractors: ["أنّها حطّمت رقمًا قياسيًّا في السباق", "أنّها غاضبة من مريم", "أنّها لم تتدرّب بما فيه الكفاية"], tier: .hard, grades: 7...7),
                BankQuestion(prompt: "أيّ صفة من صفات ليان تبرز في القصّة؟", correctAnswer: "الاهتمام بالآخرين", distractors: ["حبّ المنافسة", "الكسل", "قلّة الصبر"], tier: .medium, grades: 7...7),
            ]),
        ReadingPassage(
            id: "ms7_camel", tier: .medium, grades: 7...7,
            text: "الجمل متكيّف تكيّفًا جيّدًا مع الحياة في الصحراء. وخلافًا لما يظنّه كثيرون، لا يُخزَّن في سنامه ماء بل شحم يستطيع الجسم أن يستعمله مصدرًا للطاقة حين لا يجد غذاءً. ويقدر الجمل على الصمود مدّة طويلة بلا شرب، وحين يصل إلى الماء يشرب كمّيّة كبيرة جدًّا دفعة واحدة. وللجمل رموش طويلة ومنخران يستطيع إغلاقهما، وهما يحميانه في العواصف الرمليّة. أمّا أخفافه العريضة فتمنعه من الغرق في الرمل الناعم.",
            questions: [
                BankQuestion(prompt: "بحسب النصّ، ماذا يُخزَّن في سنام الجمل؟", correctAnswer: "الشحم", distractors: ["الماء", "الهواء", "الملح"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "ما الذي يساعد الجمل على ألّا يغرق في الرمل؟", correctAnswer: "أخفافه العريضة", distractors: ["رموشه الطويلة", "سنامه الكبير", "منخراه اللذان يُغلقان"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "ما معنى «متكيّف تكيّفًا جيّدًا» في النصّ؟", correctAnswer: "مناسب جدًّا لظروف المكان", distractors: ["كبير الحجم جدًّا", "مروَّض على يد الإنسان", "مهدَّد بالانقراض"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "ما هدف النصّ؟", correctAnswer: "أن يشرح كيف يصمد الجمل في الصحراء", distractors: ["أن يقنع القارئ بتربية الجمال", "أن يروي رحلة في الصحراء", "أن يقارن بين الجمل والحصان"], tier: .hard, grades: 7...7),
            ]),
        ReadingPassage(
            id: "ms7_homework", tier: .hard, grades: 7...7,
            text: "حاولت بضع مدارس في العالم إلغاء الوظائف البيتيّة. يقول مؤيّدو الفكرة إنّ الأولاد بعد يوم دراسيّ طويل بحاجة إلى وقت للراحة واللعب والبقاء مع العائلة. ويضيفون أنّ قسمًا من التلاميذ لا يجدون من يساعدهم في البيت، ولذلك تزيد الوظائف البيتيّة الفجوات بينهم. أمّا المعارضون فيرون أنّ الوظائف البيتيّة تعلّم المسؤوليّة والاستقلاليّة، وأنّ المادّة تُنسى بسرعة بلا تمرين. وهناك من يقترح حلًّا وسطًا: وظائف قليلة، قصيرة ومشوّقة، يستطيع التلميذ إعدادها بلا مساعدة شخص بالغ.",
            questions: [
                BankQuestion(prompt: "ما إحدى حجج المؤيّدين لإلغاء الوظائف البيتيّة؟", correctAnswer: "الأولاد بحاجة إلى وقت للراحة واللعب", distractors: ["الوظائف البيتيّة تعلّم المسؤوليّة", "المادّة تُنسى بلا تمرين", "المعلّمون لا يصحّحونها"], tier: .hard, grades: 7...7),
                BankQuestion(prompt: "لماذا تزيد الوظائف البيتيّة الفجوات، بحسب المؤيّدين؟", correctAnswer: "لأنّ ليس كلّ التلاميذ يجدون مساعدة في البيت", distractors: ["لأنّها طويلة أكثر من اللازم", "لأنّها مملّة", "لأنّها تُعطى للتلاميذ المتفوّقين فقط"], tier: .hard, grades: 7...7),
                BankQuestion(prompt: "ما هو «الحلّ الوسط» المقترح؟", correctAnswer: "وظائف قليلة وقصيرة يستطيع التلميذ إعدادها وحده", distractors: ["إلغاء الوظائف البيتيّة تمامًا", "إعطاء وظائف في نهاية الأسبوع فقط", "أن يُعِدّ الأهل الوظائف"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "أيّ نوع من النصوص هو هذا النصّ؟", correctAnswer: "نصّ يعرض مواقف مختلفة في نقاش", distractors: ["قصّة عن تلميذ", "تعليمات لإعداد الوظائف", "خبر عن حدث وقع أمس"], tier: .hard, grades: 7...7),
            ]),
        ReadingPassage(
            id: "ms7_rainbow", tier: .medium, grades: 7...7,
            text: "يظهر قوس قزح حين تشرق الشمس ويكون الهواء مليئًا بقطرات الماء، مثلًا بعد المطر مباشرة. ويبدو لنا ضوء الشمس أبيض، لكنّه في الحقيقة مؤلّف من ألوان كثيرة. وحين يدخل الضوء إلى قطرة ماء ينكسر وينفصل إلى ألوان، شبيهًا بما يحدث في المنشور. ولكي نرى القوس علينا أن نقف والشمس خلفنا والقطرات أمامنا. ولذلك نرى القوس في الصباح في الغرب، وبعد الظهر — في الشرق.",
            questions: [
                BankQuestion(prompt: "متى يمكن رؤية قوس قزح، بحسب النصّ؟", correctAnswer: "حين تكون هناك شمس وقطرات ماء في الهواء", distractors: ["في الليل فقط", "حين تكون السماء ملبّدة بالغيوم تمامًا", "في الشتاء فقط"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "ممّ يتألّف ضوء الشمس؟", correctAnswer: "من ألوان كثيرة", distractors: ["من لون أبيض واحد", "من قطرات ماء", "من اللون الأصفر وحده"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "أين يجب أن تكون الشمس كي نرى قوس قزح؟", correctAnswer: "خلف الشخص الناظر", distractors: ["أمام الشخص الناظر", "فوق الغيوم بالضبط", "تحت الأفق"], tier: .hard, grades: 7...7),
                BankQuestion(prompt: "إلى أيّ جهة يُستحسن النظر لرؤية قوس قزح في الصباح؟", correctAnswer: "الغرب", distractors: ["الشرق", "الشمال", "الجنوب"], tier: .hard, grades: 7...7),
            ]),
        ReadingPassage(
            id: "ms7_letter", tier: .medium, grades: 7...7,
            text: "في صندوق قديم في بيت جدّته وجد آدم رسالة اصفرّ ورقها. كتبتها الجدّة وهي في الثانية عشرة من عمرها، بعد وقت قصير من وصولها إلى البلاد مع والديها. كتبت: «ما زلت لا أفهم كلّ الكلمات التي تقولها المعلّمة، لكنّني في كلّ يوم أفهم أكثر قليلًا. أمس قاسمتني فتاة من الصفّ شطيرتها، وقد فهمتها بلا كلمات إطلاقًا». قرأ آدم الرسالة مرّتين. وتذكّر التلميذ الجديد الذي وصل إلى صفّه قبل أسبوع، ذاك الذي يجلس دائمًا وحده في الاستراحة.",
            questions: [
                BankQuestion(prompt: "متى كتبت الجدّة الرسالة؟", correctAnswer: "بعد وقت قصير من وصولها إلى البلاد", distractors: ["حين صارت معلّمة", "في يوم زفافها", "قبل أسبوع"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "ما الذي كان صعبًا على الجدّة في المدرسة؟", correctAnswer: "أن تفهم اللغة", distractors: ["أن تجد صفّها", "أن تُعِدّ الوظائف البيتيّة", "أن تصل في الوقت"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "ماذا تقصد الجدّة بجملة «فهمتها بلا كلمات إطلاقًا»؟", correctAnswer: "أنّ العمل الطيّب شرح نفسه بنفسه", distractors: ["أنّ الفتاة لم تكن تعرف الكلام", "أنّهما تحدّثتا بلغة الإشارة", "أنّها لم ترغب في الحديث معها"], tier: .hard, grades: 7...7),
                BankQuestion(prompt: "ماذا يمكن أن نتوقّع أن يفعل آدم بعد قراءة الرسالة؟", correctAnswer: "أن يتقرّب من التلميذ الجديد في صفّه", distractors: ["أن يكتب رسالة إلى جدّته", "أن يخبّئ الرسالة في الصندوق", "أن يطلب الانتقال إلى صفّ آخر"], tier: .hard, grades: 7...7),
            ]),
        ReadingPassage(
            id: "ms7_alexandria", tier: .hard, grades: 7...7,
            text: "في مدينة الإسكندريّة بمصر عملت في العصور القديمة واحدة من أشهر المكتبات في العالم. أراد الحكّام الذين أنشأوها أن يجمعوا فيها كتبًا من كلّ الشعوب، فوفد إليها متبحّرون من بلاد كثيرة للدراسة والبحث. وكانت الكتب تُكتب حينذاك على لفائف، وكان نسخها يجري باليد. ولا يُعرف بالضبط متى دُمّرت المكتبة ولا كيف: فمن المصادر ما يصف حريقًا، ومنها ما يصف إهمالًا طويلًا. والمؤكّد أنّ ضياعها ضيّع معه معارف ومؤلّفات لم تصل إلينا.",
            questions: [
                BankQuestion(prompt: "ماذا أراد الحكّام الذين أنشأوا المكتبة؟", correctAnswer: "أن يجمعوا فيها كتبًا من كلّ الشعوب", distractors: ["أن يحفظوا فيها كنوز الذهب", "أن يعلّموا فيها أبناء الملك وحدهم", "أن ينسخوا فيها الكتب بالمطبعة"], tier: .hard, grades: 7...7),
                BankQuestion(prompt: "ماذا يقول النصّ عن دمار المكتبة؟", correctAnswer: "لا يُعرف بالضبط كيف دُمّرت", distractors: ["احترقت بالتأكيد في حريق واحد", "دُمّرت في زلزال", "ما زالت قائمة حتّى اليوم"], tier: .hard, grades: 7...7),
                BankQuestion(prompt: "ما معنى كلمة «متبحّرون» في النصّ؟", correctAnswer: "أشخاص ذوو معرفة واسعة", distractors: ["تلاميذ في مدرسة", "كتب قديمة", "حرّاس المكتبة"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "لماذا يُعدّ ضياع المكتبة كارثة؟", correctAnswer: "لأنّ معارف ومؤلّفات ضاعت ولم تصل إلينا", distractors: ["لأنّها كانت أعلى بناء في مصر", "لأنّ المدينة هُجرت بسببه", "لأنّه لم تبقَ لفائف في العالم"], tier: .hard, grades: 7...7),
            ]),
        ReadingPassage(
            id: "ms7_herbs", tier: .medium, grades: 7...7,
            text: "أتريدون حديقة أعشاب صغيرة في الشرفة؟ أوّلًا اختاروا مكانًا تصله الشمس بضع ساعات في اليوم على الأقلّ. بعد ذلك جهّزوا أصيصًا في قاعه ثقوب، كي يخرج منه الماء الزائد. املأوه بتربة الزراعة، واغرسوا الشتلات متباعدة بعضها عن بعض، ليتّسع لها مكان للنموّ. اسقوها مباشرة بعد الغرس. وفيما بعد لا تسقوها إلّا حين تجفّ التربة من الأعلى — فزيادة الماء قد تُعفّن الجذور. وبعد بضعة أسابيع ستقطفون أوّل الأوراق.",
            questions: [
                BankQuestion(prompt: "ما الذي يجب فعله أوّلًا، بحسب التعليمات؟", correctAnswer: "اختيار مكان تصله الشمس", distractors: ["سقي التربة", "غرس الشتلات", "قطف الأوراق"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "لماذا نحتاج إلى ثقوب في قاع الأصيص؟", correctAnswer: "كي يخرج منه الماء الزائد", distractors: ["كي تدخل إليه الشمس", "كي يصير الأصيص خفيفًا", "كي تخرج الجذور إلى الخارج"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "متى يُستحسن السقي بعد الغرس؟", correctAnswer: "حين تجفّ التربة من الأعلى", distractors: ["عدّة مرّات في كلّ يوم", "مرّة واحدة في الشهر فقط", "حين ينزل المطر فقط"], tier: .hard, grades: 7...7),
                BankQuestion(prompt: "ماذا قد يحدث إذا سقينا أكثر من اللازم؟", correctAnswer: "قد تتعفّن الجذور", distractors: ["تنمو الأوراق بسرعة كبيرة", "ينكسر الأصيص", "تتغيّر نكهة الأعشاب"], tier: .medium, grades: 7...7),
            ]),
        ReadingPassage(
            id: "ms7_neighbors_dog", tier: .medium, grades: 7...7,
            text: "كلّ ليلة كان كلب الجيران ينبح حتّى وقت متأخّر، فلا يستطيع كرم أن ينام. أراد الأب أن يشتكي إلى لجنة البناية، لكنّ كرم اقترح أن يجرّبوا شيئًا آخر أوّلًا. وفي اليوم التالي طرق باب الجيران. فتبيّن أنّ الزوجين يعملان في ورديّات ليليّة، وأنّ الكلب يبقى وحده فيخاف. اقترح كرم أن يتنزّه معه في المساء. ومنذ ذلك الحين يعود الكلب متعبًا هادئًا، والجيران يشكرون كرم في كلّ مناسبة، أمّا هو — فينام نومًا عميقًا.",
            questions: [
                BankQuestion(prompt: "ما كانت مشكلة كرم؟", correctAnswer: "لم يكن يستطيع النوم في الليل", distractors: ["كان يخاف من الكلاب", "الجيران صرخوا عليه", "أراد كلبًا خاصًّا به"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "لماذا كان الكلب ينبح في الليالي؟", correctAnswer: "لأنّه كان يبقى وحده ويخاف", distractors: ["لأنّه كان جائعًا", "لأنّه سمع لصوصًا", "لأنّه كان مريضًا"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "ما الفرق بين طريقة الأب وطريقة كرم؟", correctAnswer: "الأب أراد أن يشتكي، وكرم أراد أن يتحدّث أوّلًا", distractors: ["الأب أراد أن يتحدّث، وكرم أراد أن يشتكي", "كلاهما أراد الانتقال إلى شقّة أخرى", "الأب أراد أن يتبنّى الكلب"], tier: .hard, grades: 7...7),
                BankQuestion(prompt: "ما رسالة القصّة؟", correctAnswer: "أحيانًا يحلّ الحديث المشكلة أفضل من الشكوى", distractors: ["الكلاب لا تناسب الشقق", "يجب النوم باكرًا", "يُمنع ترك كلب في البيت"], tier: .hard, grades: 7...7),
            ]),
        ReadingPassage(
            id: "ms7_printing", tier: .hard, grades: 7...7,
            text: "قبل اختراع الطباعة كان كلّ كتاب يُنسخ باليد، وقد يستغرق العمل في كتاب واحد شهورًا. ولذلك كانت الكتب غالية ونادرة، ولم يكن يقدر على اقتنائها إلّا قلّة. وفي منتصف القرن الخامس عشر طوّر يوهانس غوتنبرغ في ألمانيا طريقة طباعة بحروف معدنيّة منفصلة، يمكن ترتيبها من جديد لكلّ صفحة. وهكذا أمكن طبع نسخ كثيرة من الكتاب نفسه بسرعة. فصارت الكتب أرخص، وانتشرت الأفكار الجديدة في أوروبّا أسرع من أيّ وقت مضى.",
            questions: [
                BankQuestion(prompt: "لماذا كانت الكتب غالية قبل اختراع الطباعة؟", correctAnswer: "لأنّ كلّ كتاب كان يُنسخ باليد", distractors: ["لأنّها كانت تُكتب على الذهب", "لأنّ القراءة كانت ممنوعة", "لأنّه لم يكن في العالم ورق"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "ما الجديد في طريقة غوتنبرغ؟", correctAnswer: "حروف معدنيّة منفصلة يمكن ترتيبها من جديد", distractors: ["الكتابة باليد بسرعة أكبر", "رسوم بدل الحروف", "آلة تكتب الرسائل وحدها"], tier: .hard, grades: 7...7),
                BankQuestion(prompt: "ما معنى كلمة «نادرة» في النصّ؟", correctAnswer: "لا يوجد منها إلّا القليل جدًّا", distractors: ["يسهل الحصول عليها", "مكتوبة بلغة أجنبيّة", "قديمة جدًّا"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "ما إحدى نتائج اختراع الطباعة؟", correctAnswer: "انتشرت الأفكار أسرع", distractors: ["توقّف الناس عن القراءة", "كُتبت كلّ الكتب بالألمانيّة", "صارت الكتب أغلى"], tier: .hard, grades: 7...7),
            ]),
        ReadingPassage(
            id: "ms7_virtual_water", tier: .hard, grades: 7...7,
            text: "حين نفكّر في استهلاك الماء نتذكّر الاستحمام أو الحنفيّة. لكنّ جزءًا كبيرًا من الماء الذي «نستهلكه» مخبّأ داخل المنتجات التي نشتريها. فزراعة القطن اللازم لقميص، أو زراعة العلف للأبقار التي تعطي الحليب، أو صناعة الورق — كلّها تحتاج إلى كمّيّات كبيرة من الماء. ويسمّون هذا الماء «الماء الافتراضيّ»، أي ماءً لا نراه لكنّه جزء من عمليّة الإنتاج. ويقول باحثون إنّ توفير الماء يبدأ أيضًا من خياراتنا كمستهلكين: أن نشتري ما نحتاج إليه فقط، وألّا نرمي الطعام.",
            questions: [
                BankQuestion(prompt: "ما هو «الماء الافتراضيّ» بحسب النصّ؟", correctAnswer: "ماء استُعمل في إنتاج المنتجات", distractors: ["ماء في لعبة حاسوب", "ماء يجري في الحنفيّات", "ماء البحر المالح"], tier: .hard, grades: 7...7),
                BankQuestion(prompt: "ما معنى كلمة «مخبّأ» في النصّ؟", correctAnswer: "أنّنا لا نراه", distractors: ["أنّ استعماله ممنوع", "أنّه نفد تمامًا", "أنّه يكلّف مالًا كثيرًا"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "أيّ مثال يَرِد في النصّ على منتَج يحتاج إنتاجه إلى ماء؟", correctAnswer: "قميص من القطن", distractors: ["سيّارة كهربائيّة", "هاتف محمول", "كرة قدم"], tier: .medium, grades: 7...7),
                BankQuestion(prompt: "بماذا يوصي الكاتب كلّ واحد منّا؟", correctAnswer: "أن نشتري ما نحتاج إليه فقط وألّا نرمي الطعام", distractors: ["أن نتوقّف عن الاستحمام", "أن نزرع القطن في البيت", "أن نشرب ماءً أقلّ"], tier: .hard, grades: 7...7),
            ]),
        ReadingPassage(
            id: "ms8_phones", tier: .hard, grades: 8...8,
            text: "هل ينبغي إخراج الهواتف الذكيّة من المدارس؟ برأيي نعم. تُظهر دراسات كثيرة أنّ تنبيهات الهاتف تشتّت الانتباه حتّى حين لا نردّ عليها، وأنّ التركيز يعود ببطء. وأكثر من ذلك، ففي الاستراحات ينظر كثير من التلاميذ إلى الشاشة بدل أن يلعبوا ويتحادثوا. صحيح أنّ هناك من يقول إنّ الهاتف أداة تعلّم مهمّة، وإنّ على الأهل أن يصلوا إلى أولادهم في حالات الطوارئ. غير أنّ في المدرسة حواسيب لأغراض التعلّم، وفي حالة الطوارئ يمكن دائمًا التوجّه إلى السكرتاريّة. لذلك يبدو أنّ فائدة إبعاد الهواتف أكبر من ضررها.",
            questions: [
                BankQuestion(prompt: "ما موقف الكاتب؟", correctAnswer: "يجب إخراج الهواتف من المدارس", distractors: ["كلّ تلميذ يحتاج إلى هاتف في الصفّ", "الهاتف هو أفضل أداة تعلّم", "لا موقف له في الموضوع"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "أيّ حجّة للطرف الآخر يذكرها النصّ؟", correctAnswer: "في حالات الطوارئ على الأهل أن يصلوا إلى أولادهم", distractors: ["التنبيهات تشتّت الانتباه", "في الاستراحات ينظر التلاميذ إلى الشاشة", "التركيز يعود ببطء"], tier: .hard, grades: 8...8),
                BankQuestion(prompt: "ما وظيفة أداة الربط «غير أنّ» في النصّ؟", correctAnswer: "أن تقدّم ردًّا على حجّة الطرف الآخر", distractors: ["أن تضيف حجّة أخرى مؤيّدة", "أن تقدّم سببًا", "أن تلخّص النصّ"], tier: .hard, grades: 8...8),
                BankQuestion(prompt: "ما معنى عبارة «تشتّت الانتباه»؟", correctAnswer: "تُفقِد التركيز", distractors: ["تساعد على التذكّر", "تهدّئ التلاميذ", "تغيّر رأينا"], tier: .medium, grades: 8...8),
            ]),
        ReadingPassage(
            id: "ms8_plastic", tier: .hard, grades: 8...8,
            text: "تصل إلى البحر كلّ سنة كمّيّات هائلة من نفايات البلاستيك. والبلاستيك لا يتحلّل كما تتحلّل ورقة شجر أو قشرة برتقالة؛ بل يتكسّر إلى قطع أصغر فأصغر، حتّى يصير جسيمات دقيقة تُسمّى البلاستيك الدقيق. وقد تبتلع الكائنات البحريّة هذه الجسيمات أو تعلق في الأكياس والشِّباك. وقد وُجدت جسيمات كهذه في الأسماك وفي ملح البحر أيضًا. وللتخفيف من المشكلة يُوصى بتقليل استعمال الأدوات ذات الاستعمال الواحد، وبإعادة التدوير، وبالمشاركة في تنظيف الشواطئ.",
            questions: [
                BankQuestion(prompt: "ماذا يحدث للبلاستيك في البحر، بحسب النصّ؟", correctAnswer: "يتكسّر إلى قطع أصغر فأصغر", distractors: ["يختفي خلال أيّام قليلة", "يتحوّل إلى غذاء للأسماك", "يغرق ويبقى سليمًا"], tier: .hard, grades: 8...8),
                BankQuestion(prompt: "ما معنى كلمة «يتحلّل» في النصّ؟", correctAnswer: "يتفكّك ويزول في الطبيعة", distractors: ["يحترق بسهولة", "يطفو على سطح الماء", "مصنوع من مادّة طبيعيّة"], tier: .hard, grades: 8...8),
                BankQuestion(prompt: "لماذا يذكر الكاتب ورقة الشجر وقشرة البرتقالة؟", correctAnswer: "كي يقارن بمادّة تتحلّل فعلًا", distractors: ["لأنّهما تلوّثان البحر أيضًا", "لأنّ البلاستيك يُصنع منهما", "لأنّ الأسماك تأكلهما"], tier: .hard, grades: 8...8),
                BankQuestion(prompt: "أيّ توصية لا تَرِد في النصّ؟", correctAnswer: "التوقّف عن أكل الأسماك", distractors: ["تقليل الأدوات ذات الاستعمال الواحد", "إعادة التدوير", "المشاركة في تنظيف الشواطئ"], tier: .medium, grades: 8...8),
            ]),
        ReadingPassage(
            id: "ms8_ben_yehuda", tier: .hard, grades: 8...8,
            text: "في أواخر القرن التاسع عشر كانت العبريّة أساسًا لغة صلاة ودراسة وكتابة، ولم يكن أحد تقريبًا يتحدّث بها في الحياة اليوميّة. وقد آمن إليعيزر بن يهودا، الذي وصل إلى البلاد سنة 1881، بأنّ شعبًا يعود إلى أرضه يحتاج إلى لغة واحدة مشتركة. فقرّر أن يتحدّث في بيته بالعبريّة وحدها، وأسّس لجنة عملت على توليد كلمات جديدة. وألّف بن يهودا قاموسًا كبيرًا للّغة العبريّة، واقترح كلمات جديدة لمفاهيم لم يكن لها اسم. أمّا ابنه إيتمار بن آفي فيُلقَّب في الغالب بـ«أوّل طفل عبريّ»، لأنّه نشأ والعبريّة لغته الأمّ.",
            questions: [
                BankQuestion(prompt: "ما كان حال العبريّة في أواخر القرن التاسع عشر، بحسب النصّ؟", correctAnswer: "لم يكن أحد تقريبًا يتحدّث بها في الحياة اليوميّة", distractors: ["كانت لغة الحديث عند الجميع", "لم يكن أحد يعرف القراءة بها", "كان استعمالها ممنوعًا"], tier: .hard, grades: 8...8),
                BankQuestion(prompt: "لماذا كانت هناك حاجة إلى لغة مشتركة، برأي بن يهودا؟", correctAnswer: "لأنّ شعبًا يعود إلى أرضه يحتاج إلى لغة واحدة", distractors: ["لأنّه أراد أن يؤلّف كتبًا", "لأنّه لم تكن هناك كلمات للصلاة", "لأنّ الحكم طلب ذلك"], tier: .hard, grades: 8...8),
                BankQuestion(prompt: "ما معنى «توليد كلمات» في النصّ؟", correctAnswer: "إنشاء كلمات جديدة", distractors: ["محو كلمات قديمة", "الترجمة إلى لغات أخرى", "كتابة الكلمات بخطّ اليد"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "لماذا يُلقَّب إيتمار بن آفي بـ«أوّل طفل عبريّ»؟", correctAnswer: "لأنّه نشأ والعبريّة لغته الأمّ", distractors: ["لأنّه أوّل من وُلد في القدس", "لأنّه هو الذي كتب القاموس", "لأنّه كان أوّل تلميذ في مدرسة"], tier: .medium, grades: 8...8),
            ]),
        ReadingPassage(
            id: "ms8_trophy", tier: .hard, grades: 8...8,
            text: "كانت الكأس الذهبيّة على الرفّ في غرفة رامي، وكلّما دخل الغرفة أشاح بنظره عنها. في المباراة النهائيّة رأى الجميع الكرة تلمس يده قبل الهدف، الجميع إلّا الحكم. احتفل الفريق، وعانقه المدرّب، ونشرت الصحيفة المحلّيّة صورته. وقال لنفسه: «هذا جزء من اللعبة». لكن أمس، حين طلب أخوه الصغير أن يلعب معه وسأله: «كيف يسجّل المرء هدفًا مثل الأبطال؟»، لم يعرف رامي بماذا يجيب.",
            questions: [
                BankQuestion(prompt: "ماذا حدث في المباراة النهائيّة؟", correctAnswer: "لمست الكرة يد رامي قبل الهدف", distractors: ["استُبدل رامي في منتصف المباراة", "خسر فريق رامي", "ألغى الحكم الهدف"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "لماذا يشيح رامي بنظره عن الكأس؟", correctAnswer: "لأنّ الفوز يذكّره بأنّه لم يفز بنزاهة", distractors: ["لأنّ الكأس مكسورة", "لأنّه لا يحبّ كرة القدم", "لأنّ الكأس ليست له بل لأخيه"], tier: .hard, grades: 8...8),
                BankQuestion(prompt: "ماذا تصف جملة «هذا جزء من اللعبة» التي يقولها رامي لنفسه؟", correctAnswer: "محاولة لتبرير ما حدث", distractors: ["شرحًا لقوانين كرة القدم", "فرحًا صادقًا بالفوز", "قرارًا بالتوقّف عن اللعب"], tier: .hard, grades: 8...8),
                BankQuestion(prompt: "لماذا لم يعرف رامي بماذا يجيب أخاه؟", correctAnswer: "لأنّه لا يشعر بأنّه بطل حقيقيّ", distractors: ["لأنّه لم يسمع السؤال", "لأنّ أخاه أصغر من أن يلعب", "لأنّه نسي كيف يسجّل الأهداف"], tier: .hard, grades: 8...8),
            ]),
        ReadingPassage(
            id: "ms8_galileo", tier: .hard, grades: 8...8,
            text: "في سنة 1609 سمع العالِم الإيطاليّ غاليليو غاليلي بأداة جديدة تقرّب الأجسام البعيدة، فصنع لنفسه مقرابًا محسَّنًا. وحين وجّهه إلى السماء اكتشف جبالًا وفوّهات على القمر، وأربعة أقمار تدور حول كوكب المشتري. وقد عزّزت اكتشافاته الفكرة التي طرحها كوبرنيكوس، وهي أنّ الأرض والكواكب تدور حول الشمس، لا الشمس حول الأرض. وكانت هذه الفكرة مخالفة للموقف السائد في ذلك العصر، وفي سنة 1633 قُدّم غاليليو إلى المحاكمة وأُلزم بالتراجع عن أقواله.",
            questions: [
                BankQuestion(prompt: "ماذا اكتشف غاليليو على القمر؟", correctAnswer: "جبالًا وفوّهات", distractors: ["بحارًا من الماء", "غابات كثيفة", "ضوءًا ينبعث منه هو"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "ماذا قالت فكرة كوبرنيكوس، بحسب النصّ؟", correctAnswer: "الأرض تدور حول الشمس", distractors: ["الشمس تدور حول الأرض", "القمر أكبر من الشمس", "لا أقمار لكوكب المشتري"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "كيف أثّرت اكتشافات غاليليو في فكرة كوبرنيكوس؟", correctAnswer: "عزّزتها", distractors: ["أثبتت أنّها خاطئة", "لم تكن ذات صلة بها", "دفعت كوبرنيكوس إلى التراجع"], tier: .hard, grades: 8...8),
                BankQuestion(prompt: "ما معنى عبارة «التراجع عن أقواله»؟", correctAnswer: "أن يعلن أنّه لم يعد يتمسّك برأيه", distractors: ["أن يعيد أقواله مرّة أخرى", "أن يعود إلى إيطاليا", "أن يشرح أقواله بالتفصيل"], tier: .hard, grades: 8...8),
            ]),
        ReadingPassage(
            id: "ms8_beach_news", tier: .medium, grades: 8...8,
            text: "يوم الجمعة الماضي شارك نحو مئتي متطوّع في تنظيف الشاطئ الشماليّ للمدينة. وخلال ثلاث ساعات جُمعت عشرات الأكياس من النفايات، معظمها قناني بلاستيك وأغطية وبقايا شِباك صيد. وقالت إحدى المشاركات، وهي تلميذة في الصفّ الثامن: «لم أصدّق كم من النفايات على شاطئ يبدو نظيفًا». وبرأيي، ينبغي أن يُقام حدث كهذا كلّ شهر، لا مرّة واحدة في السنة. وأفادت البلديّة بأنّها تدرس وضع حاويات إضافيّة في الشاطئ مع اقتراب الصيف.",
            questions: [
                BankQuestion(prompt: "ما كان معظم النفايات التي جُمعت؟", correctAnswer: "قناني بلاستيك", distractors: ["قشور فاكهة", "صحف قديمة", "قطع زجاج"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "أيّ جملة في النصّ تعبّر عن رأي لا عن حقيقة؟", correctAnswer: "ينبغي أن يُقام الحدث كلّ شهر", distractors: ["شارك نحو مئتي متطوّع", "جُمعت عشرات الأكياس", "استمرّ التنظيف ثلاث ساعات"], tier: .hard, grades: 8...8),
                BankQuestion(prompt: "ما الذي فاجأ التلميذة المشاركة؟", correctAnswer: "كمّيّة النفايات في شاطئ يبدو نظيفًا", distractors: ["عدد المتطوّعين", "أنّ التنظيف جرى يوم الجمعة", "أنّ البلديّة لم تحضر"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "ماذا تدرس البلديّة أن تفعل؟", correctAnswer: "أن تضع حاويات إضافيّة في الشاطئ", distractors: ["أن تغلق الشاطئ في الصيف", "أن تنظّم تنظيفًا كلّ شهر", "أن تفرض غرامات على الصيّادين"], tier: .hard, grades: 8...8),
            ]),
        ReadingPassage(
            id: "ms8_teen_sleep", tier: .hard, grades: 8...8,
            text: "يشكو كثير من الأهل أنّ أبناءهم المراهقين ينامون في وقت متأخّر ويصعب عليهم النهوض في الصباح. ويوضّح علماء النوم أنّ الساعة البيولوجيّة تتغيّر في سنّ المراهقة: إذ لا يبدأ الجسم بالشعور بالتعب إلّا في ساعة متأخّرة من المساء. وفي الوقت نفسه ما زال المراهقون بحاجة إلى ساعات نوم كثيرة — وبحسب التوصيات المتّبعة، بين ثماني ساعات وعشر ساعات في الليلة. وقد تؤخّر الشاشات في ساعات المساء بدء النوم أكثر. لذلك يُوصى بإبعاد الهاتف عن السرير، وبالمحافظة على ساعة نوم ثابتة، حتّى في نهايات الأسبوع.",
            questions: [
                BankQuestion(prompt: "ما الذي يتغيّر في سنّ المراهقة، بحسب النصّ؟", correctAnswer: "لا يشعر الجسم بالتعب إلّا في ساعة متأخّرة", distractors: ["يحتاج المراهقون إلى ساعات نوم أقلّ", "يصير النهوض في الصباح أسهل", "يتوقّف الجسم عن التعب"], tier: .hard, grades: 8...8),
                BankQuestion(prompt: "كم ساعة نوم يُوصى بها للمراهقين، بحسب النصّ؟", correctAnswer: "بين ثماني ساعات وعشر ساعات", distractors: ["بين أربع ساعات وستّ", "ستّ ساعات بالضبط", "أكثر من اثنتي عشرة ساعة"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "ما معنى كلمة «تؤخّر» في النصّ؟", correctAnswer: "تجعل شيئًا يحدث في وقت لاحق", distractors: ["تجعل شيئًا أسهل", "توقف شيئًا تمامًا", "تجعل شيئًا يحدث بسرعة أكبر"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "ما هدف النصّ؟", correctAnswer: "أن يشرح ظاهرة ويقترح طرقًا للتعامل معها", distractors: ["أن يروي قصّة مراهق لم ينم", "أن يقنع القرّاء بإلغاء المدرسة", "أن يصف بحثًا عن الحيوانات"], tier: .hard, grades: 8...8),
            ]),
        ReadingPassage(
            id: "ms8_old_tree", tier: .hard, grades: 8...8,
            text: "في طرف القرية وقفت بلّوطة عجوز، أغصانها ممدودة كذراعَي جدّ ينتظر أحفاده. تسلّقتها أجيال من الأولاد، وحفروا في جذعها حروفًا، واستراحوا في ظلّها في أيّام الصيف. وحين تقرّر شقّ شارع في المكان، تجمّع أهل القرية حول الشجرة. روى الكبار ذكرياتهم، وعلّق الأولاد على أغصانها بطاقات. وفي النهاية تقرّر تحويل مسار الشارع قليلًا نحو الشمال. وبقيت الشجرة واقفة، ساكنة كعادتها، كأنّها لا تدري كم من القلوب خفقت من أجلها.",
            questions: [
                BankQuestion(prompt: "بماذا يشبّه الكاتب أغصان الشجرة؟", correctAnswer: "بذراعَي جدّ ينتظر أحفاده", distractors: ["بسقف بيت", "بشارع طويل", "بحروف محفورة"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "ماذا فعل السكّان حين تقرّر شقّ الشارع؟", correctAnswer: "تجمّعوا حول الشجرة", distractors: ["قطعوا الشجرة بأنفسهم", "غادروا القرية", "ساعدوا في شقّ الشارع"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "ما معنى جملة «كم من القلوب خفقت من أجلها»؟", correctAnswer: "كم من الناس أحبّوها وخافوا عليها", distractors: ["كم من الناس سكنوا في القرية", "كم من الطيور عشّشت عليها", "كم مرّة أرادوا قطعها"], tier: .hard, grades: 8...8),
                BankQuestion(prompt: "إلامَ ترمز الشجرة في القصّة؟", correctAnswer: "إلى الذكريات والصلة بين الأجيال", distractors: ["إلى تطوّر القرية", "إلى برد الشتاء", "إلى مشاكل المواصلات"], tier: .hard, grades: 8...8),
            ]),
        ReadingPassage(
            id: "ms8_dead_sea", tier: .hard, grades: 8...8,
            text: "البحر الميت هو أخفض مكان على سطح اليابسة، ومنسوب مياهه ينخفض عامًا بعد عام. ومصدر مياهه الرئيسيّ هو نهر الأردن، غير أنّ قسمًا كبيرًا من مياه الأردن وروافده حُوِّل على مرّ السنين إلى الشرب والزراعة، ولذلك يصل إلى البحر ماء أقلّ بكثير. ويُضاف إلى ذلك أنّ المعادن تُستخرج في برك التبخير في قسمه الجنوبيّ، وهذه العمليّة تزيد فقدان الماء. ومن النتائج نشوء بالوعات أرضيّة — حفر تنفتح في الأرض فجأة قرب الشاطئ.",
            questions: [
                BankQuestion(prompt: "ما مصدر المياه الرئيسيّ للبحر الميت، بحسب النصّ؟", correctAnswer: "نهر الأردن", distractors: ["البحر المتوسّط", "مياه الأمطار وحدها", "ينابيع في النقب"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "ما معنى كلمة «حُوِّل» في النصّ؟", correctAnswer: "وُجِّه إلى مكان آخر", distractors: ["تلوّث", "تبخّر في الشمس", "صار مالحًا"], tier: .hard, grades: 8...8),
                BankQuestion(prompt: "أيّ سبب لانخفاض المنسوب يَرِد في النصّ؟", correctAnswer: "استخراج المعادن في برك التبخير", distractors: ["الزلازل", "بناء الفنادق", "تلوّث المياه"], tier: .hard, grades: 8...8),
                BankQuestion(prompt: "ما هي البالوعات الأرضيّة، بحسب النصّ؟", correctAnswer: "حفر تنفتح في الأرض فجأة", distractors: ["ينابيع ماء حارّة", "جزر من الملح", "نباتات تنمو على الشاطئ"], tier: .medium, grades: 8...8),
            ]),
        ReadingPassage(
            id: "ms8_inertia", tier: .hard, grades: 8...8,
            text: "لماذا يندفع ركّاب الحافلة إلى الأمام حين يكبح السائق فجأة؟ الجواب في القانون الذي صاغه إسحاق نيوتن، والمعروف بقانون القصور الذاتيّ. فبحسب هذا القانون، يواصل الجسم المتحرّك حركته بالسرعة نفسها وفي الاتّجاه نفسه، ما دامت لا تؤثّر فيه قوّة تغيّر حركته. وحين تتوقّف الحافلة «يريد» جسمنا أن يواصل الحركة إلى الأمام. وحزام الأمان هو الذي يطبّق على الجسم القوّة التي توقفه مع المركبة، ولهذا فهو ينقذ الأرواح.",
            questions: [
                BankQuestion(prompt: "من صاغ قانون القصور الذاتيّ، بحسب النصّ؟", correctAnswer: "إسحاق نيوتن", distractors: ["غاليليو غاليلي", "ألبرت أينشتاين", "يوهانس غوتنبرغ"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "ماذا يقرّر قانون القصور الذاتيّ؟", correctAnswer: "الجسم المتحرّك يواصل حركته حتّى تغيّرها قوّة", distractors: ["كلّ جسم يتوقّف وحده بعد وقت", "الجسم الثقيل يتحرّك دائمًا أسرع", "الحافلة تسير أسرع من الإنسان"], tier: .hard, grades: 8...8),
                BankQuestion(prompt: "لماذا يندفع الركّاب إلى الأمام عند الكبح؟", correctAnswer: "لأنّ أجسامهم تواصل الحركة إلى الأمام", distractors: ["لأنّ السائق يدفعهم", "لأنّ الحافلة تتسارع", "لأنّ المقاعد تتحرّك إلى الخلف"], tier: .hard, grades: 8...8),
                BankQuestion(prompt: "ما وظيفة حزام الأمان، بحسب النصّ؟", correctAnswer: "أن يطبّق قوّة توقف الجسم مع المركبة", distractors: ["أن يجعل المركبة تكبح", "أن يزيد سرعة المركبة", "أن يهدّئ الركّاب"], tier: .medium, grades: 8...8),
            ]),
        ReadingPassage(
            id: "ms8_ada", tier: .hard, grades: 8...8,
            text: "وُلدت آدا لوفلايس في إنجلترا سنة 1815، في زمن لم يكن يُسمح فيه للنساء تقريبًا بالاشتغال بالعلم. وقد شجّعتها أمّها على تعلّم الرياضيّات منذ صغرها. وحين تعرّفت إلى المخترع تشارلز باباج، الذي صمّم آلة حاسبة ميكانيكيّة، حمست للفكرة. وكتبت آدا ملاحظات مفصّلة عن الآلة، ضمّنتها وصفًا لسلسلة من العمليّات تستطيع الآلة أن تنفّذها لحساب أعداد. وبفضل هذه الملاحظات تُعَدّ في نظر كثيرين واحدة من أوائل المبرمجين في التاريخ — قبل أن يُبنى الحاسوب الأوّل.",
            questions: [
                BankQuestion(prompt: "من شجّع آدا على تعلّم الرياضيّات؟", correctAnswer: "أمّها", distractors: ["تشارلز باباج", "معلّمتها في المدرسة", "الملكة"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "ما كان حال النساء في العلم في زمن آدا؟", correctAnswer: "لم يكن يُسمح لهنّ بالاشتغال به تقريبًا", distractors: ["كنّ معظم العلماء", "النساء وحدهنّ درسن الرياضيّات", "نلن جوائز كثيرة"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "ماذا كتبت آدا في ملاحظاتها؟", correctAnswer: "سلسلة عمليّات تستطيع الآلة أن تنفّذها", distractors: ["رسالة إلى الملكة", "قصّة عن آلة الزمن", "خطّة لبناء مصنع"], tier: .hard, grades: 8...8),
                BankQuestion(prompt: "لماذا يشدّد الكاتب على «قبل أن يُبنى الحاسوب الأوّل»؟", correctAnswer: "كي يُظهر كم سبقت زمنها", distractors: ["كي يقول إنّها بنت حاسوبًا", "كي ينتقد تشارلز باباج", "كي يشرح كيف يعمل الحاسوب"], tier: .hard, grades: 8...8),
            ]),
        ReadingPassage(
            id: "ms8_wallet", tier: .hard, grades: 8...8,
            text: "في طريقها إلى البيت وجدت سارة محفظة على المقعد. كان فيها أوراق نقديّة وبطاقة اعتماد وصورة طفل صغير. قالت لها صديقتها نور: «لم يرَ أحد. خذي المال وارمي المحفظة». نظرت سارة إلى الصورة وسألت نفسها بماذا كانت ستشعر لو كانت المحفظة محفظة أمّها. ووجدت في المحفظة بطاقة هويّة فيها عنوان، وفي المساء قرعت الباب. فتحت امرأة مسنّة، وانفجرت بالبكاء، وروت أنّ في المحفظة كلّ المال الذي ادّخرته للشهر.",
            questions: [
                BankQuestion(prompt: "بماذا أشارت نور على سارة؟", correctAnswer: "أن تأخذ المال وترمي المحفظة", distractors: ["أن تذهب إلى الشرطة", "أن تبحث عن صاحب المحفظة", "أن تترك المحفظة على المقعد"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "ما الذي ساعد سارة على أن تقرّر ما تفعل؟", correctAnswer: "تخيّلت أنّ المحفظة محفظة أمّها", distractors: ["خافت أن يكون أحد قد رآها", "أقنعتها نور", "أرادت أن تنال جائزة"], tier: .hard, grades: 8...8),
                BankQuestion(prompt: "كيف وجدت سارة صاحبة المحفظة؟", correctAnswer: "بحسب عنوان في بطاقة هويّة داخل المحفظة", distractors: ["بحسب صورة الطفل", "بواسطة بطاقة الاعتماد", "سألت الجيران"], tier: .medium, grades: 8...8),
                BankQuestion(prompt: "لماذا انفجرت المرأة بالبكاء؟", correctAnswer: "لأنّها استعادت المال الذي كان مهمًّا جدًّا لها", distractors: ["لأنّ المال اختفى من المحفظة", "لأنّها لم تكن تعرف سارة", "لأنّ الصورة تمزّقت"], tier: .hard, grades: 8...8),
            ]),
        ReadingPassage(
            id: "balloon_gift", tier: .easy, grades: 1...2,
            text: "عند آدم بالون أزرق كبير. طار البالون إلى السماء، فاشترى له أبوه بالونًا جديدًا.",
            questions: [
                BankQuestion(prompt: "ما لون بالون آدم؟", correctAnswer: "أزرق", distractors: ["أحمر", "أخضر", "أصفر"], tier: .easy, grades: 1...2),
                BankQuestion(prompt: "إلى أين طار البالون؟", correctAnswer: "إلى السماء", distractors: ["إلى البحر", "إلى السطح", "إلى الشجرة"], tier: .easy, grades: 1...2),
                BankQuestion(prompt: "من اشترى لآدم بالونًا جديدًا؟", correctAnswer: "أبوه", distractors: ["أمّه", "جدّه", "أخوه"], tier: .easy, grades: 1...2),
            ]),
        ReadingPassage(
            id: "little_bird_nest", tier: .easy, grades: 1...2,
            text: "بنى عصفور صغير عشًّا على الشجرة في الساحة. ووضعت له مريم فتات خبز على حافّة النافذة.",
            questions: [
                BankQuestion(prompt: "ماذا بنى العصفور؟", correctAnswer: "عشًّا", distractors: ["خيمة", "حفرة", "جحرًا"], tier: .easy, grades: 1...2),
                BankQuestion(prompt: "أين بنى العصفور العشّ؟", correctAnswer: "على الشجرة", distractors: ["على السطح", "على حافّة النافذة", "داخل البيت"], tier: .easy, grades: 1...2),
                BankQuestion(prompt: "ماذا وضعت مريم للعصفور؟", correctAnswer: "فتات خبز", distractors: ["ماءً", "بذورًا", "كعكة"], tier: .easy, grades: 1...2),
            ]),
        ReadingPassage(
            id: "galilee_trip", tier: .medium, grades: 3...4,
            text: "يوم الأربعاء خرج الصفّ الثالث في رحلة سنويّة إلى الجليل. سار التلاميذ في طريق ضيّقة بين أزهار بنفسجيّة وبيضاء. ورأوا في الطريق شلّالًا صغيرًا، فتوقّف الجميع ليصوّروه. وحدّثتهم المعلّمة سارة أنّ الشلّال في الشتاء أقوى بأضعاف. وفي نهاية الرحلة أكلوا جميعًا البوظة في المحطّة الأخيرة.",
            questions: [
                BankQuestion(prompt: "إلى أين خرج الصفّ في الرحلة؟", correctAnswer: "إلى الجليل", distractors: ["إلى النقب", "إلى القدس", "إلى إيلات"], tier: .medium, grades: 3...4),
                BankQuestion(prompt: "ماذا رأى التلاميذ في الطريق؟", correctAnswer: "شلّالًا صغيرًا", distractors: ["مغارة مظلمة", "نهرًا واسعًا", "قطيع ماعز"], tier: .medium, grades: 3...4),
                BankQuestion(prompt: "ماذا حدّثتهم المعلّمة عن الشلّال؟", correctAnswer: "أنّه في الشتاء أقوى", distractors: ["أنّه الأكبر في البلاد", "أنّ الاقتراب منه ممنوع", "أنّه يجفّ في الصيف"], tier: .medium, grades: 3...4),
            ]),
        ReadingPassage(
            id: "birthday_cookies", tier: .medium, grades: 3...4,
            text: "اقترب عيد ميلاد الأب، وأراد جاد أن يفاجئه. نهض باكرًا في الصباح وأعدّ مع أمّه بسكويت الشوكولاتة. وانتشرت الرائحة الحلوة في البيت كلّه وكادت توقظ الأب. وخبّأ جاد البسكويت في علبة عليها شريط أحمر. وحين فتح الأب العلبة، عانق جادًا عناقًا كبيرًا.",
            questions: [
                BankQuestion(prompt: "لمن أعدّ جاد المفاجأة؟", correctAnswer: "لأبيه", distractors: ["لأمّه", "لجدّته", "لأخيه"], tier: .medium, grades: 3...4),
                BankQuestion(prompt: "ماذا أعدّ جاد وأمّه؟", correctAnswer: "بسكويت الشوكولاتة", distractors: ["كعكة الجبن", "الفطائر المحلّاة", "سلطة فواكه"], tier: .medium, grades: 3...4),
                BankQuestion(prompt: "أين خبّأ جاد البسكويت؟", correctAnswer: "في علبة عليها شريط أحمر", distractors: ["في الثلّاجة", "تحت السرير", "في الفرن"], tier: .medium, grades: 3...4),
            ]),
        ReadingPassage(
            id: "desert_stars", tier: .hard, grades: 5...6,
            text: "في عطلة الصيف سافرت عائلة كرم لتمضية ليلة تخييم في صحراء يهودا. وبعد أن نصبوا الخيام أشعل الأب نارًا صغيرة، وشوى الأولاد فيها البطاطا. وحين حلّ الظلام أطفأوا المصابيح، فحدث أمر عجيب: امتلأت السماء بآلاف النجوم. وشرحت الأمّ أنّ أضواء الشوارع في المدينة تحجب معظم النجوم، ولذلك لا نرى هناك إلّا قليلًا منها. وفجأة أشارت نور الصغيرة إلى شهاب، فتمكّن الجميع من أن يتمنّوا أمنية. وقبل النوم وعد الأولاد بأن يعودوا إلى الصحراء في كلّ سنة.",
            questions: [
                BankQuestion(prompt: "ماذا شوى الأولاد على النار؟", correctAnswer: "البطاطا", distractors: ["المارشميلو", "الذرة", "النقانق"], tier: .hard, grades: 5...6),
                BankQuestion(prompt: "لماذا لا نرى في المدينة إلّا قليلًا من النجوم؟", correctAnswer: "لأنّ أضواء الشوارع تحجبها", distractors: ["لأنّ في سماء المدينة نجومًا أقلّ", "لأنّ الغيوم فوق المدينة كثيفة", "لأنّ المباني عالية جدًّا"], tier: .hard, grades: 5...6),
                BankQuestion(prompt: "ماذا يمكن أن نتعلّم من النصّ عن العائلة؟", correctAnswer: "أنّ الرحلة أعجبتها كثيرًا", distractors: ["أنّها خافت من الظلام", "أنّها لا تحبّ التخييم", "أنّها تسكن في الصحراء"], tier: .hard, grades: 5...6),
            ]),
        ReadingPassage(
            id: "bird_migration", tier: .hard, grades: 5...6,
            text: "مرّتين في السنة تعبر سماء إسرائيل ملايين الطيور المهاجرة. في الخريف تطير من أوروبّا الباردة إلى إفريقيا الدافئة، وفي الربيع تعود في الاتّجاه المعاكس. وتقع إسرائيل تمامًا على محور الهجرة، ولذلك هي من أهمّ محطّات الطيور في العالم. ففي سهل الحولة يتوقّف عشرات آلاف طيور الكركيّ للراحة والأكل قبل متابعة الرحلة. وتستغلّ الطيور تيّارات الهواء الدافئة كي تحلّق دون أن ترفرف بأجنحتها، فتوفّر بذلك جهدًا كبيرًا. ويثبّت الباحثون على بعضها حلقات صغيرة لتتبّع مسارها. وهكذا يعرف العلماء إلى أين يصل كلّ سرب ومتى يعود.",
            questions: [
                BankQuestion(prompt: "إلى أين تطير الطيور في الخريف؟", correctAnswer: "إلى إفريقيا الدافئة", distractors: ["إلى أوروبّا الباردة", "إلى أمريكا", "تبقى في إسرائيل"], tier: .hard, grades: 5...6),
                BankQuestion(prompt: "لماذا تستغلّ الطيور تيّارات الهواء الدافئة؟", correctAnswer: "كي توفّر جهدًا في الرحلة", distractors: ["كي تتدفّأ في البرد", "كي تطير على ارتفاع أقلّ", "كي تستحمّ في الهواء"], tier: .hard, grades: 5...6),
                BankQuestion(prompt: "ماذا يمكن أن نتعلّم من النصّ؟", correctAnswer: "أنّ إسرائيل محطّة مهمّة في مسار الهجرة", distractors: ["أنّ الطيور المهاجرة تحبّ الأماكن الباردة", "أنّ طيور الكركيّ تعيش في إسرائيل طوال السنة", "أنّ مراقبة الطيور المهاجرة ممنوعة"], tier: .hard, grades: 5...6),
            ]),
    ]
}
