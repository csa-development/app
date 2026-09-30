class Certificate(models.Model):
    CERTIFICATE_TYPES = [
        ('CSP', 'Cybersecurity Service Provider'),
        ('CE', 'Cybersecurity Establishment'),
        ('CP', 'Cybersecurity Professional'),
    ]

    certificate_number = models.CharField(max_length=100, unique=True)
    certificate_type = models.CharField(max_length=10, choices=CERTIFICATE_TYPES)
    holder_name = models.CharField(max_length=200)
    organisation = models.CharField(max_length=200, blank=True)
    issue_date = models.DateField()
    expiry_date = models.DateField()
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return f"{self.certificate_number} - {self.holder_name}"