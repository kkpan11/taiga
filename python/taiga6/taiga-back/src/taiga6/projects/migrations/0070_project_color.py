# Generated by Django 2.2.24 on 2021-10-08 05:28

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('projects', '0069_auto_20210930_1349'),
    ]

    operations = [
        migrations.AddField(
            model_name='project',
            name='color',
            field=models.IntegerField(default=1, verbose_name='color'),
        ),
    ]