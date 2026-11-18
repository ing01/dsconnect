import { rememberClientReturnTo, takeClientReturnTo } from '../clientSession';

describe('return to the form after the client login', () => {
  beforeEach(() => window.sessionStorage.clear());

  it('remembers a form of the Customer Area and gives it back once', () => {
    rememberClientReturnTo('/app/client/forms/7');

    expect(takeClientReturnTo()).toBe('/app/client/forms/7');
    expect(takeClientReturnTo()).toBeNull();
  });

  it('never keeps another address (no open redirect)', () => {
    rememberClientReturnTo('https://evil.example/app/client/forms/7');
    rememberClientReturnTo('/app/client/tickets');
    rememberClientReturnTo('//evil.example');

    expect(takeClientReturnTo()).toBeNull();
  });

  it('survives storage that is blocked', () => {
    const spy = vi
      .spyOn(Storage.prototype, 'setItem')
      .mockImplementation(() => {
        throw new Error('blocked');
      });

    expect(() => rememberClientReturnTo('/app/client/forms/7')).not.toThrow();
    spy.mockRestore();
  });
});
