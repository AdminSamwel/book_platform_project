from django.db import migrations


FREE_FEATURES = [
    'Soma vitabu vyote vya bure (free books)',
    'Fikia hadi vitabu 3 visivyo vya bure kwa majaribio',
    'Tumia mfumo wote wa kusoma na maoni',
]

BASIC_FEATURES = [
    'Vitabu vyote vya kiwango cha Basic na vya bure',
    'Fikia hadi vitabu 5 kwa wakati mmoja',
    'Usomaji wa sauti (audio books) wa kiwango cha Basic',
    'Hakuna matangazo',
]

PRO_FEATURES = [
    'Vitabu vyote vya Basic na Pro, pamoja na vya bure',
    'Vitabu visivyo na kikomo (unlimited)',
    'Upakuaji wa sauti kwa ajili ya kusikiliza nje ya mtandao',
    'Kipaumbele cha huduma kwa wateja',
]

PREMIUM_FEATURES = [
    'Vitabu vyote ikiwemo vya kipekee vya Premium',
    'Vitabu visivyo na kikomo (unlimited)',
    'Upatikanaji wa mapema wa vitabu vipya',
    'Maudhui maalum ya kipekee kutoka kwa waandishi',
    'Kipaumbele cha juu cha huduma kwa wateja',
]


def seed_levels(apps, schema_editor):
    SubscriptionPlan = apps.get_model('subscriptions', 'SubscriptionPlan')

    # Sasisha mipango iliyopo kulingana na jina
    level_map = {
        'Basic': (1, BASIC_FEATURES),
        'Pro': (2, PRO_FEATURES),
        'Premium': (3, PREMIUM_FEATURES),
    }
    for plan in SubscriptionPlan.objects.all():
        if plan.name in level_map:
            level, features = level_map[plan.name]
            plan.level = level
            plan.features = features
            plan.save(update_fields=['level', 'features'])

    # Tengeneza mpango wa Bure (Free) kama haupo
    SubscriptionPlan.objects.get_or_create(
        name='Free',
        defaults={
            'price': 0,
            'duration_days': 36500,
            'max_books': 3,
            'level': 0,
            'features': FREE_FEATURES,
        },
    )


def reverse_seed(apps, schema_editor):
    SubscriptionPlan = apps.get_model('subscriptions', 'SubscriptionPlan')
    SubscriptionPlan.objects.filter(name='Free', level=0).delete()


class Migration(migrations.Migration):

    dependencies = [
        ('subscriptions', '0002_alter_subscriptionplan_options_and_more'),
    ]

    operations = [
        migrations.RunPython(seed_levels, reverse_seed),
    ]
