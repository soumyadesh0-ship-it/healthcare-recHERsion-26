"""Focused chatbot checks; all provider calls are mocked."""
import asyncio
import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

from fastapi import HTTPException
from google.genai import errors

from service.main import ChatRequest, chat


class ChatTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.env = patch.dict('os.environ', {'GEMINI_API_KEY': 'test-only'})
        self.env.start()
        self.addCleanup(self.env.stop)
        self.client_patch = patch('service.main.genai.Client')
        self.client = self.client_patch.start()
        self.addCleanup(self.client_patch.stop)
        self.ai = MagicMock()
        self.ai.models.generate_content = AsyncMock(
            return_value=SimpleNamespace(text='Hello from AuraCare'))
        self.client.return_value.aio.__aenter__ = AsyncMock(return_value=self.ai)
        self.client.return_value.aio.__aexit__ = AsyncMock(return_value=False)

    async def test_reply_and_client_cleanup(self):
        result = await chat(ChatRequest(prompt='Hello'))
        self.assertEqual(result.response, 'Hello from AuraCare')
        self.ai.models.generate_content.assert_awaited_once()
        self.client.return_value.aio.__aexit__.assert_awaited_once()

    async def test_provider_errors_are_safe_and_actionable(self):
        for upstream, expected in [(429, 429), (503, 503), (504, 504), (403, 502)]:
            with self.subTest(upstream=upstream):
                self.ai.models.generate_content.side_effect = errors.APIError(
                    upstream, {'error': {'message': 'private provider details'}})
                with self.assertRaises(HTTPException) as caught:
                    await chat(ChatRequest(prompt='Hello'))
                self.assertEqual(caught.exception.status_code, expected)
                self.assertNotIn('private provider details', caught.exception.detail)

    async def test_stalled_provider_is_cancelled_at_deadline(self):
        async def stalled(**kwargs):
            await asyncio.Event().wait()

        self.ai.models.generate_content.side_effect = stalled
        with patch('service.main.CHAT_TIMEOUT_SECONDS', 0.01):
            with self.assertRaises(HTTPException) as caught:
                await chat(ChatRequest(prompt='Hello'))
        self.assertEqual(caught.exception.status_code, 504)
        self.client.return_value.aio.__aexit__.assert_awaited_once()

    async def test_missing_key_does_not_call_provider(self):
        with patch.dict('os.environ', {'GEMINI_API_KEY': ''}):
            with self.assertRaises(HTTPException) as caught:
                await chat(ChatRequest(prompt='Hello'))
        self.assertEqual(caught.exception.status_code, 503)
        self.client.assert_not_called()


if __name__ == '__main__':
    unittest.main()
