/// Source-checked educational drafts. Not reviewed or endorsed by a clinician.
/// Source URLs were checked on 2026-10-25; this is not a clinical review date.
class ArticleSection {
  const ArticleSection(this.heading, this.body);
  final String heading, body;
}

class ArticleSource {
  const ArticleSource(this.title, this.url);
  final String title, url;
}

class EducationalArticle {
  const EducationalArticle({
    required this.topic,
    required this.introduction,
    required this.sections,
    required this.question,
    required this.answer,
    required this.sources,
  });
  final String topic, introduction, question, answer;
  final List<ArticleSection> sections;
  final List<ArticleSource> sources;
  String get searchableText => [
    topic,
    introduction,
    ...sections.map((s) => '${s.heading} ${s.body}'),
    question,
    answer,
  ].join(' ').toLowerCase();
  static const checkedOn = '25 October 2026';
  static const disclaimer =
      'General education, not a diagnosis or a substitute for professional medical advice. Source-checked draft; clinical editorial review pending.';
}

EducationalArticle _article(
  String topic,
  String intro,
  String stage,
  String physical,
  String emotional,
  String care,
  String consult,
  String question,
  String answer,
  List<ArticleSource> sources,
) => EducationalArticle(
  topic: topic,
  introduction: intro,
  sections: [
    ArticleSection('What happens', stage),
    ArticleSection('Physical experiences', physical),
    ArticleSection('Emotional experiences', emotional),
    ArticleSection('General care', care),
    ArticleSection('When to get medical help', consult),
  ],
  question: question,
  answer: answer,
  sources: sources,
);

abstract final class ArticleCatalog {
  static final Map<String, EducationalArticle> articles = {
    for (final article in _all) article.topic: article,
  };
  static final List<EducationalArticle> _all = [
    _article(
      'Puberty & adolescence',
      'Puberty is the transition toward an adult body. People develop at different times.',
      'Hormonal changes bring breast development, body hair and eventually periods. A different pace from friends does not by itself mean something is wrong.',
      'Breast growth and underarm or pubic hair can appear before the first period.',
      'Changes can feel unfamiliar. You can ask questions privately or with someone you trust.',
      'Learn about period products before you need them. A trusted adult or school nurse can help you prepare.',
      'Ask a clinician about development that seems unusually early or delayed. Seek advice if periods have not started by 15, or by 13 without other puberty signs.',
      'Do people start together?',
      'No. Puberty and the first period follow individual timelines.',
      [
        const ArticleSource(
          'NHS: puberty timing',
          'https://www.nhs.uk/conditions/early-or-delayed-puberty/',
        ),
        const ArticleSource(
          'NHS: first periods',
          'https://www.nhs.uk/conditions/periods/starting-periods/',
        ),
      ],
    ),
    _article(
      'First periods & menstrual health',
      'A period is bleeding as the womb lining is shed. The first bleeding day begins a new cycle.',
      'Early periods can take time to settle into a pattern. A single calendar prediction cannot tell exactly when bleeding will begin.',
      'Bleeding amounts and cramps vary. Flow that repeatedly disrupts daily life deserves attention.',
      'Some people notice mood changes around periods. Record your experience without assuming every feeling is hormonal.',
      'Choose a comfortable period product and follow its instructions. Keep spare supplies and note dates or troublesome symptoms.',
      'Arrange assessment for pain or bleeding that interferes with daily activities, bleeding between periods, or a major change in your usual pattern.',
      'Which product should I choose?',
      'Pads, period underwear, tampons and cups are options. Follow product guidance and choose what feels manageable.',
      [
        const ArticleSource(
          'NHS: first periods',
          'https://www.nhs.uk/conditions/periods/starting-periods/',
        ),
        const ArticleSource(
          'NHS: period problems',
          'https://www.nhs.uk/conditions/periods/period-problems/',
        ),
      ],
    ),
    _article(
      'Hormonal & reproductive health',
      'Hormones help coordinate the ovaries and womb. Calendar dates cannot measure hormone levels.',
      'Oestrogen helps prepare the womb lining; after ovulation, progesterone supports it. If pregnancy does not occur, hormone changes allow a period to begin.',
      'Discharge can change over a cycle. Clear or white discharge without an unpleasant smell may be normal.',
      'Feelings can change for many reasons. A symptom diary can support a conversation without proving a hormonal cause.',
      'Record changes in your own words. Avoid scented vaginal products and washing inside the vagina.',
      'Get assessed for unusual discharge, pelvic pain, bleeding after sex or between periods. Do not diagnose an infection from appearance alone.',
      'Does discharge prove ovulation?',
      'No. A change may occur around ovulation, but it cannot confirm it.',
      [
        const ArticleSource(
          'NHS: menstrual cycle',
          'https://www.nhs.uk/conditions/periods/fertility-in-the-menstrual-cycle/',
        ),
        const ArticleSource(
          'NHS: vaginal discharge',
          'https://www.nhs.uk/symptoms/vaginal-discharge/',
        ),
      ],
    ),
    _article(
      'Fertility & preconception',
      'Preconception care is a chance to discuss health before a possible pregnancy.',
      'Conception involves sperm fertilising an egg. Timing varies, especially with irregular cycles; app estimates do not confirm fertility.',
      'Regular bleeding does not assess every aspect of fertility. Both partners may need assessment when pregnancy is difficult.',
      'Trying to conceive may feel uncertain or stressful. Support is appropriate at any stage.',
      'Discuss medicines, existing conditions, vaccinations and recommended supplements with a clinician. Do not stop a prescribed medicine on your own.',
      'Seek earlier advice for irregular or absent periods or known reproductive conditions. CDC advises assessment after a year of trying under 35, or six months from age 35.',
      'Can an app rule out fertility problems?',
      'No. A personal history and clinical assessment are needed.',
      [
        const ArticleSource(
          'NHS: preparing for pregnancy',
          'https://www.nhs.uk/pregnancy/trying-for-a-baby/trying-to-get-pregnant/',
        ),
        const ArticleSource(
          'CDC: fertility questions',
          'https://www.cdc.gov/reproductive-health/infertility-faq/',
        ),
      ],
    ),
    _article(
      'Pregnancy',
      'Every pregnancy is different. Symptoms alone cannot confirm pregnancy or tell whether it is progressing normally.',
      'A developing pregnancy brings changes throughout the body. Arrange antenatal care with an appropriate local maternity service.',
      'Nausea, tiredness, breast tenderness and more frequent urination can occur. Some people have few early symptoms.',
      'Feelings may vary. Tell your maternity professional if worry or low mood is difficult to manage.',
      'Keep maternity appointments and ask before changing medicines or using supplements. Discuss symptoms rather than relying on a calendar.',
      'Get urgent medical help for severe persistent headache, chest pain, breathing difficulty, fainting, severe abdominal pain, fever or significant bleeding. Report reduced baby movements promptly once movements have become established.',
      'Is severe vomiting just normal sickness?',
      'Not always. Seek assessment if you cannot keep fluids down or feel seriously unwell.',
      [
        const ArticleSource(
          'NHS: early pregnancy symptoms',
          'https://www.nhs.uk/pregnancy/trying-for-a-baby/signs-and-symptoms-that-might-mean-youre-pregnant/',
        ),
        const ArticleSource(
          'NHS: pregnancy warning signs',
          'https://www.nhs.uk/pregnancy/common-symptoms/pregnancy-symptoms-you-need-to-get-help-for/',
        ),
      ],
    ),
    _article(
      'Postpartum',
      'Postpartum means the time after childbirth. Physical recovery and emotional adjustment do not follow one fixed timetable.',
      'The womb recovers, hormones change and bleeding called lochia gradually reduces. Caesarean or birth injuries may need additional follow-up.',
      'Soreness, constipation, urine leakage and interrupted sleep can occur. Tell your care team about symptoms that worry you.',
      'Brief baby blues can happen. Low mood starting later or continuing beyond two weeks needs professional attention.',
      'Accept practical help, rest when possible and attend follow-up care. Ask your midwife about wound care, pelvic health and emotional support.',
      'Seek immediate care for very heavy bleeding, fever, chest pain, breathing difficulty, severe headache or one-sided leg swelling. Get urgent help for thoughts of harming yourself or the baby.',
      'Do I need to wait for a routine check?',
      'No. Concerning symptoms deserve earlier assessment, including during the year after birth.',
      [
        const ArticleSource(
          'NHS: recovery after birth',
          'https://www.nhs.uk/pregnancy/labour-and-birth/your-body/',
        ),
        const ArticleSource(
          'NHS: early days after birth',
          'https://www.nhs.uk/pregnancy/labour-and-birth/early-days/',
        ),
        const ArticleSource(
          'CDC: maternal warning signs',
          'https://www.cdc.gov/hearher/maternal-warning-signs/index.html',
        ),
      ],
    ),
    _article(
      'Perimenopause',
      'Perimenopause is the transition leading to menopause. Experiences differ widely.',
      'Hormonal changes can alter the spacing or heaviness of periods before they eventually stop.',
      'Hot flushes, night sweats, vaginal dryness and disturbed sleep may occur.',
      'Anxiety, low mood and concentration difficulties may affect daily life. Support is available.',
      'Regular sleep routines, activity, a balanced diet and talking with supportive people may help. A clinician can discuss individual treatment options.',
      'Discuss symptoms that affect your life, palpitations or increasingly heavy bleeding. Do not assume every new symptom is caused by menopause.',
      'Can symptoms happen while I still have periods?',
      'Yes. Perimenopause starts before periods have ended.',
      [
        const ArticleSource(
          'NHS: transition symptoms',
          'https://www.nhs.uk/conditions/menopause-and-perimenopause/symptoms/',
        ),
        const ArticleSource(
          'NHS: general menopause care',
          'https://www.nhs.uk/conditions/menopause-and-perimenopause/things-you-can-do/',
        ),
      ],
    ),
    _article(
      'Menopause',
      'Menopause is generally identified after 12 months without periods, when another cause does not explain their absence.',
      'Ovarian hormone levels change. Hormonal contraception can make bleeding patterns harder to interpret.',
      'Flushes, sleep difficulties and vaginal dryness may persist. Not everyone has troublesome symptoms.',
      'Low mood or anxiety may need support. You do not have to manage disruptive symptoms alone.',
      'Discuss symptom management and long-term health with a clinician. Maintain activity, regular rest and a varied diet; ask before using herbal products.',
      'Have any vaginal bleeding after menopause assessed, even a small amount or a single episode. Request help for symptoms affecting daily life.',
      'Does treatment suit everyone?',
      'No. Options depend on symptoms, preferences and medical history; discuss benefits and risks individually.',
      [
        const ArticleSource(
          'NHS: menopause symptoms',
          'https://www.nhs.uk/conditions/menopause-and-perimenopause/symptoms/',
        ),
        const ArticleSource(
          'NHS: self-care options',
          'https://www.nhs.uk/conditions/menopause-and-perimenopause/things-you-can-do/',
        ),
        const ArticleSource(
          'NHS: bleeding after menopause',
          'https://www.nhs.uk/symptoms/post-menopausal-bleeding/',
        ),
      ],
    ),
    _article(
      'Later-life wellbeing',
      'Reproductive and pelvic health still matter after menopause and throughout ageing.',
      'Bone loss can accelerate after menopause. Pelvic support tissues may also change over time.',
      'Vaginal dryness, urine leakage or pelvic pressure can occur. A vaginal bulge or difficulty emptying the bladder needs assessment.',
      'Pain or leakage can affect confidence and intimacy. Discuss these concerns without embarrassment.',
      'Ask about appropriate activity, bone-health assessment and pelvic-floor support. Care should reflect your abilities and priorities.',
      'Seek assessment for vaginal bleeding after menopause, a vaginal lump, persistent pelvic discomfort or bladder problems. New symptoms should not simply be dismissed as ageing.',
      'Must I put up with leakage?',
      'No. A clinician can assess causes and discuss pelvic-health support and treatment.',
      [
        const ArticleSource(
          'NHS: bone health',
          'https://www.nhs.uk/conditions/osteoporosis/',
        ),
        const ArticleSource(
          'NHS: pelvic support',
          'https://www.nhs.uk/conditions/pelvic-organ-prolapse/',
        ),
        const ArticleSource(
          'NHS: postmenopausal bleeding',
          'https://www.nhs.uk/symptoms/post-menopausal-bleeding/',
        ),
      ],
    ),
    _article(
      'PCOS',
      'Polycystic ovary syndrome is a hormonal and metabolic condition with varied symptoms. A quiz cannot diagnose it.',
      'Higher androgen levels and disrupted ovulation can affect periods and fertility. Ovarian cysts are not required in every case.',
      'Possible experiences include irregular periods, acne, extra facial or body hair and hair thinning. Symptoms differ between people.',
      'PCOS can affect body image and emotional wellbeing, including anxiety or depression. These concerns deserve care too.',
      'Discuss manageable activity, nutrition, menstrual health and longer-term metabolic checks with your care team. Support should be individual and nonjudgmental.',
      'See a clinician for persistent irregular or absent periods, possible PCOS symptoms, fertility concerns or distress. Similar symptoms may have other causes.',
      'Does PCOS mean pregnancy is impossible?',
      'No. Many people conceive; individual fertility assessment and support may help.',
      [
        const ArticleSource(
          'WHO: polycystic ovary syndrome',
          'https://www.who.int/news-room/fact-sheets/detail/polycystic-ovary-syndrome',
        ),
      ],
    ),
    _article(
      'Symptoms & terminology',
      'A symptom is something you experience; it is not the same as a confirmed diagnosis.',
      'A useful history describes what changed, when it began, how often it happens and how it affects your life.',
      'Flow, pain and discharge can vary. New discharge changes, bleeding between periods or pain with urination should be discussed with a clinician.',
      'Uncertainty can be unsettling. Recording observations in plain language is enough; you do not need to diagnose yourself.',
      'Keep a brief diary and note medicines or relevant dates. Describe the effect on daily activities rather than relying only on a severity number.',
      'Get help for persistent or disruptive symptoms. Sudden severe illness needs urgent care rather than waiting to collect more app data.',
      'Does an unlogged day mean symptom-free?',
      'No. It means no observation was recorded.',
      [
        const ArticleSource(
          'NHS: describing period problems',
          'https://www.nhs.uk/conditions/periods/period-problems/',
        ),
        const ArticleSource(
          'NHS: discharge changes',
          'https://www.nhs.uk/symptoms/vaginal-discharge/',
        ),
      ],
    ),
    _article(
      'Appointment preparation',
      'A short list of priorities can help you make the most of a healthcare conversation.',
      'An appointment may involve discussing symptoms, examination or tests. Ask what each step is for and what happens next.',
      'Bring the dates and details of symptoms you want to discuss, plus a list of medicines and supplements.',
      'It is reasonable to feel nervous. Ask for communication support or take someone you trust if you would like.',
      'Choose two or three key questions. Ask for unfamiliar terms to be explained and take notes about the plan.',
      'Ask who to contact if symptoms worsen and when results are expected. Do not wait for a routine appointment if you need urgent care.',
      'What should I clarify before leaving?',
      'Check the next steps, expected results and how to ask further questions.',
      [
        const ArticleSource(
          'NHS: preparing questions',
          'https://www.nhs.uk/nhs-services/gps/what-to-ask-your-doctor/',
        ),
        const ArticleSource(
          'NIH: appointment preparation',
          'https://health.nih.gov/health-topics-a-z/prepare-for-appointment',
        ),
      ],
    ),
  ];
}
