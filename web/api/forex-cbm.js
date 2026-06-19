module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Cache-Control', 'public, max-age=300');

  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }

  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const response = await fetch('https://forex.cbm.gov.mm/api/latest');
    const body = await response.text();
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    res.status(response.status).send(body);
  } catch (_) {
    res.status(502).json({ error: 'Failed to fetch CBM forex rates' });
  }
};
