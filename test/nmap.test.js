const { startSecurityTest, Time } = require('./sdk');

test(
  'finds open 3000 port of juiceshop',
  async () => {
    const securityTest = await startSecurityTest({
      context: 'JuiceShopPortScan',
      metaData: {},
      name: 'nmap',
      target: {
        name: 'JuiceShop Container',
        location: 'juice-shop',
        attributes: {
          NMAP_PARAMETER: '-Pn',
        },
      },
    });

    const { report } = securityTest;

    const [finding1, finding2, ...otherFindings] = report.findings.map(
      ({ description, category, name, osi_layer, severity }) => ({
        description,
        category,
        name,
        osi_layer,
        severity,
      })
    );

    expect(finding1).toMatchObject({
      description: 'Port 3000 is open using tcp protocol.',
      category: 'Open Port',
      name: 'ppp',
      osi_layer: 'NETWORK',
      severity: 'INFORMATIONAL',
    });

    expect(finding2).toMatchObject({
      category: 'Host',
      description: 'Found a host',
      name: 'Host: juice-shop',
      osi_layer: 'NETWORK',
      severity: 'INFORMATIONAL',
    });

    expect(otherFindings).toEqual([]);
  },
  1 * Time.Minute
);

test(
  'finds 3 open ports of bodgeit',
  async () => {
    const securityTest = await startSecurityTest({
      context: 'BodgeItPortScan',
      metaData: {},
      name: 'nmap',
      target: {
        name: 'BodgeIt Container',
        location: 'bodgeit',
        attributes: {
          NMAP_PARAMETER: '-Pn',
        },
      },
    });

    const { report } = securityTest;
    const [
      finding1,
      finding2,
      finding3,
      finding4,
      ...otherFindings
    ] = report.findings;

    expect(finding1).toMatchObject({
      description: 'Port 8009 is open using tcp protocol.',
      category: 'Open Port',
      severity: 'INFORMATIONAL',
    });

    expect(finding2).toMatchObject({
      description: 'Port 8080 is open using tcp protocol.',
      category: 'Open Port',
      severity: 'INFORMATIONAL',
    });

    expect(finding3).toMatchObject({
      description: 'Port 8443 is open using tcp protocol.',
      category: 'Open Port',
      severity: 'INFORMATIONAL',
    });

    expect(finding4).toMatchObject({
      category: 'Host',
      description: 'Found a host',
      location: 'bodgeit',
      name: 'Host: bodgeit',
      osi_layer: 'NETWORK',
      severity: 'INFORMATIONAL',
    });

    expect(otherFindings).toEqual([]);
  },
  1 * Time.Minute
);
