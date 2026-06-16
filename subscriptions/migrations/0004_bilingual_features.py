from django.db import migrations


FEATURES_BY_LEVEL = {
    0: [
        {'sw': 'Soma vitabu vyote vya bure (free books)',
         'en': 'Read all free books'},
        {'sw': 'Fikia hadi vitabu 3 visivyo vya bure kwa majaribio',
         'en': 'Access up to 3 paid books for trial'},
        {'sw': 'Tumia mfumo wote wa kusoma na maoni',
         'en': 'Use the full reading and comments system'},
    ],
    1: [
        {'sw': 'Vitabu vyote vya kiwango cha Basic na vya bure',
         'en': 'All Basic-tier books plus free books'},
        {'sw': 'Fikia hadi vitabu 5 kwa wakati mmoja',
         'en': 'Access up to 5 books at a time'},
        {'sw': 'Usomaji wa sauti (audio books) wa kiwango cha Basic',
         'en': 'Basic-tier audiobook listening'},
        {'sw': 'Hakuna matangazo', 'en': 'No ads'},
    ],
    2: [
        {'sw': 'Vitabu vyote vya Basic na Pro, pamoja na vya bure',
         'en': 'All Basic and Pro books, plus free books'},
        {'sw': 'Vitabu visivyo na kikomo (unlimited)',
         'en': 'Unlimited books'},
        {'sw': 'Upakuaji wa sauti kwa ajili ya kusikiliza nje ya mtandao',
         'en': 'Audio downloads for offline listening'},
        {'sw': 'Kipaumbele cha huduma kwa wateja',
         'en': 'Priority customer support'},
    ],
    3: [
        {'sw': 'Vitabu vyote ikiwemo vya kipekee vya Premium',
         'en': 'All books including exclusive Premium titles'},
        {'sw': 'Vitabu visivyo na kikomo (unlimited)',
         'en': 'Unlimited books'},
        {'sw': 'Upatikanaji wa mapema wa vitabu vipya',
         'en': 'Early access to new books'},
        {'sw': 'Maudhui maalum ya kipekee kutoka kwa waandishi',
         'en': 'Exclusive special content from authors'},
        {'sw': 'Kipaumbele cha juu cha huduma kwa wateja',
         'en': 'Top-priority customer support'},
    ],
}

def make_bilingual(apps, schema_editor):
    SubscriptionPlan = apps.get_model('subscriptions', 'SubscriptionPlan')
    for plan in SubscriptionPlan.objects.all():
        if plan.level in FEATURES_BY_LEVEL:
            plan.features = FEATURES_BY_LEVEL[plan.level]
            plan.save(update_fields=['features'])


def reverse_bilingual(apps, schema_editor):
    SubscriptionPlan = apps.get_model('subscriptions', 'SubscriptionPlan')
    for plan in SubscriptionPlan.objects.all():
        if plan.level in FEATURES_BY_LEVEL:
            plan.features = [f['sw'] for f in FEATURES_BY_LEVEL[plan.level]]
            plan.save(update_fields=['features'])


class Migration(migrations.Migration):

    dependencies = [
        ('subscriptions', '0003_seed_plan_levels'),
    ]

    operations = [
        migrations.RunPython(make_bilingual, reverse_bilingual),
    ]
